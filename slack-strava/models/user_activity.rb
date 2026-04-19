class UserActivity < Activity
  field :start_date, type: DateTime
  field :start_date_local, type: DateTime
  field :start_date_local_utc_offset, type: Integer
  field :timezone, type: String

  belongs_to :user, inverse_of: :activities
  embeds_one :map
  embeds_one :weather
  embeds_many :photos

  index(user_id: 1, start_date: 1)
  index(user_id: 1, strava_id: 1)
  index(user_id: 1, bragged_at: 1, start_date: 1)
  index('map._id' => 1)

  before_validation :validate_team

  def hidden?
    (private? && !user.private_activities?) ||
      (visibility == 'only_me' && !user.private_activities?) ||
      (visibility == 'followers_only' && !user.followers_only_activities?)
  end

  def start_date_local_in_local_time
    start_date_local_utc_offset ? start_date_local.getlocal(start_date_local_utc_offset) : start_date_local
  end

  def start_date_local_s
    return unless start_date_local

    start_date_local_in_local_time.strftime('%A, %B %d, %Y at %I:%M %p')
  end

  def parent_thread(channel_id)
    super(channel_id, :start_date_local, start_date_local_in_local_time)
  end

  def brag!
    return if bragged_at

    if hidden?
      logger.info "Skipping #{user}, #{self}, private."
      update_attributes!(bragged_at: Time.now.utc)
      []
    else
      logger.info "Bragging about #{user}, #{self}."
      connected_channels = user.connected_channels
      rc = if connected_channels
             connected_channels.map { |channel|
               channel_id = channel['id']
               unless user.sync_activities_for_channel?(channel_id)
                 logger.info "Skipping #{user} in #{channel_id}, sync disabled for channel."
                 next
               end
               allowed_types = team.channel_activity_types_for(channel_id)
               unless allowed_types.empty? || allowed_types.any? { |t| t.casecmp(type.to_s).zero? }
                 logger.info "Skipping #{user} in #{channel_id}, activity type #{type} not in #{allowed_types}."
                 next
               end
               channel_user_limit = team.channel_max_activities_per_user_per_day_for(channel_id)
               if channel_user_limit
                 user_count_today = Activity.where(
                   team_id: team.id,
                   user_id: user.id,
                   :bragged_at.gte => team.now.beginning_of_day,
                   'channel_messages.channel' => channel_id
                 ).count
                 if user_count_today >= channel_user_limit
                   logger.info "#{user} reached the per-channel daily activity limit of #{channel_user_limit} in #{channel_id}."
                   next
                 end
               end
               if team.max_activities_per_channel_per_day
                 channel_count_today = Activity.where(
                   team_id: team.id,
                   :bragged_at.gte => team.now.beginning_of_day,
                   'channel_messages.channel' => channel_id
                 ).count
                 if channel_count_today >= team.max_activities_per_channel_per_day
                   logger.info "Channel #{channel_id} reached the daily activity limit of #{team.max_activities_per_channel_per_day}."
                   next
                 end
               end
               brag_to_channel!(channel)
             }.flatten.compact
           else
             []
           end
      update_attributes!(bragged_at: Time.now.utc, channel_messages: rc)
      rc
    end
  rescue Slack::Web::Api::Errors::SlackError => e
    case e.message
    when 'not_in_channel', 'account_inactive' then
      logger.warn "Bragging to #{user} failed, #{e.message}."
      NewRelic::Agent.notice_error(e, custom_params: { team: user.team.to_s, user: user.to_s, activity: to_s })
      nil
    else
      raise e
    end
  end

  def rebrag!
    return unless channel_messages

    logger.info "Rebragging about #{user}, #{self}."
    rc = channel_messages.map { |channel_message| rebrag_to_channel!(channel_message) }.compact
    update_attributes!(channel_messages: rc)
    rc
  end

  def unbrag!
    return unless channel_messages

    logger.info "Unbragging about #{user}, #{self}."
    user.delete!(channel_messages)
    update_attributes!(channel_messages: [])
    nil
  end

  def detailed_attrs_from_strava(response)
    {
      strava_id: response.id,
      name: response.name,
      calories: response.calories,
      distance: response.distance,
      moving_time: response.moving_time,
      elapsed_time: response.elapsed_time,
      average_speed: response.average_speed,
      max_speed: response.max_speed,
      average_heartrate: response.average_heartrate,
      max_heartrate: response.max_heartrate,
      pr_count: response.pr_count,
      type: response.sport_type,
      total_elevation_gain: response.total_elevation_gain,
      private: response.private,
      visibility: response.visibility,
      description: response.description,
      device: response.device_name,
      gear: response.gear&.name,
      start_date: response.start_date,
      start_date_local: response.start_date_local,
      start_date_local_utc_offset: response.start_date_local.utc_offset,
      timezone: response.timezone,
      photos: response.photos&.primary ? [Photo.summary_attrs_from_strava(response.photos&.primary)] : []
    }
  end

  def brag_to_channel!(channel)
    channel_id = channel['id']
    rc = user.inform_channel!(summary_message(channel_id), channel, parent_thread(channel_id))
    details = details_message(channel_id)
    if rc && details
      details_rc = user.inform_channel!(details, channel, rc[:ts])
      rc = rc.merge(details_ts: details_rc[:ts]) if details_rc
    end
    rc
  end

  def rebrag_to_channel!(channel_message)
    channel_id = channel_message.channel
    if channel_message.details_ts
      summary_rc = user.update!(to_slack_summary(channel_id), [channel_message]).first
      details_msg = to_slack_details(channel_id).merge(channel: channel_id, ts: channel_message.details_ts, as_user: true)
      logger.info "Updating details thread '#{details_msg.to_json}' to #{user.team} on ##{channel_id}."
      new_details_ts = user.team.slack_client.chat_update(details_msg)['ts']
      { ts: summary_rc[:ts], channel: channel_id, details_ts: new_details_ts }
    else
      user.update!(to_slack(channel_id), [channel_message]).first
    end
  end

  def activity_thread?(channel_id)
    team.channel_threads_for(channel_id) == 'activity'
  end

  def summary_message(channel_id)
    activity_thread?(channel_id) ? to_slack_summary(channel_id) : to_slack(channel_id)
  end

  def details_message(channel_id)
    return unless activity_thread?(channel_id)

    msg = to_slack_details(channel_id)
    msg if msg[:blocks].any?
  end

  def summary_attrs_from_strava(response)
    {
      strava_id: response.id,
      name: response.name,
      distance: response.distance,
      moving_time: response.moving_time,
      elapsed_time: response.elapsed_time,
      average_speed: response.average_speed,
      max_speed: response.max_speed,
      average_heartrate: response.average_heartrate,
      max_heartrate: response.max_heartrate,
      pr_count: response.pr_count,
      type: response.sport_type,
      total_elevation_gain: response.total_elevation_gain,
      private: response.private,
      visibility: response.visibility,
      start_date: response.start_date,
      start_date_local: response.start_date_local,
      start_date_local_utc_offset: response.start_date_local.utc_offset,
      timezone: response.timezone
    }
  end

  def attrs_from_strava(response)
    case response
    when Strava::Models::SummaryActivity
      summary_attrs_from_strava(response)
    when Strava::Models::DetailedActivity
      detailed_attrs_from_strava(response)
    else
      raise "Unexpected #{response.class}."
    end
  end

  def update_from_strava(response)
    assign_attributes(attrs_from_strava(response))
    map_response = Map.attrs_from_strava(response.map)
    map ? map.assign_attributes(map_response) : build_map(map_response)
    self
  end

  def self.create_from_strava!(user, response)
    activity = UserActivity.where(strava_id: response.id, team_id: user.team.id, user_id: user.id).first
    activity ||= UserActivity.new(strava_id: response.id, team_id: user.team.id, user_id: user.id)
    activity.update_from_strava(response)
    return unless activity.changed?

    activity.map.update!
    activity.update_weather!
    activity.save!
    activity
  end

  def display_title_s(channel_id = nil)
    if display_field?(ActivityFields::TITLE, channel_id) && display_field?(ActivityFields::URL, channel_id)
      if /\p{Emoji_Presentation}/ =~ name
        "*#{name}* <#{strava_url}|…>"
      else
        "*<#{strava_url}|#{name || strava_id}>*"
      end
    elsif display_field?(ActivityFields::TITLE, channel_id)
      "*#{name || strava_id}*"
    elsif display_field?(ActivityFields::URL, channel_id)
      "*<#{strava_url}|#{strava_id}>*"
    end
  end

  def display_medal_s(channel_id = nil)
    return unless display_field?(ActivityFields::MEDAL, channel_id)

    user.medal_s(type)
  end

  def display_user_s(channel_id = nil)
    return unless display_field?(ActivityFields::USER, channel_id)

    "<@#{user.user_name}>"
  end

  def display_user_with_medal_s(channel_id = nil)
    ary = [
      display_athlete_s(channel_id),
      display_user_s(channel_id),
      display_medal_s(channel_id)
    ].compact

    ary.any? ? ary.join(' ') : nil
  end

  def display_date_s(channel_id = nil)
    return unless display_field?(ActivityFields::DATE, channel_id)

    start_date_local_s
  end

  def display_athlete_s(channel_id = nil)
    return unless display_field?(ActivityFields::ATHLETE, channel_id) && user.athlete

    if /\p{Emoji_Presentation}/ =~ user.athlete.name
      "#{user.athlete.name} <#{user.athlete.strava_url}|…>"
    else
      "<#{user.athlete.strava_url}|#{user.athlete.name || user.athlete.id}>"
    end
  end

  def display_context_s(channel_id = nil)
    ary = [
      display_user_with_medal_s(channel_id),
      display_date_s(channel_id)
    ].compact

    ary.any? ? ary.join(' on ') : nil
  end

  def context_block(channel_id = nil)
    elements = []
    elements << { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name.to_s } if user.athlete && display_field?(ActivityFields::ATHLETE, channel_id)
    elements << { type: 'mrkdwn', text: display_context_s(channel_id) }

    {
      type: 'context',
      elements: elements
    }
  end

  def to_slack(channel_id = nil)
    {
      blocks: to_slack_blocks(channel_id),
      attachments: []
    }
  end

  def to_slack_summary(channel_id = nil)
    {
      blocks: to_slack_summary_blocks(channel_id),
      attachments: []
    }
  end

  def to_slack_details(channel_id = nil)
    {
      blocks: to_slack_details_blocks(channel_id),
      attachments: []
    }
  end

  # https://docs.slack.dev/reference/block-kit/composition-objects/text-object
  MAX_SLACK_TEXT_OBJECT_TEXT_LENGTH = 3000

  def truncated_description
    return description if description.length < MAX_SLACK_TEXT_OBJECT_TEXT_LENGTH

    "#{description[0...(MAX_SLACK_TEXT_OBJECT_TEXT_LENGTH - 2)]} …"
  end

  def to_slack_blocks(channel_id = nil)
    to_slack_summary_blocks(channel_id) + to_slack_details_blocks(channel_id)
  end

  def to_slack_summary_blocks(channel_id = nil)
    blocks = []
    blocks << { type: 'section', text: { type: 'mrkdwn', text: display_title_s(channel_id) } }
    blocks << context_block(channel_id) if display_field?(ActivityFields::MEDAL, channel_id) || display_field?(ActivityFields::ATHLETE, channel_id) || display_field?(ActivityFields::USER, channel_id) || display_field?(ActivityFields::DATE, channel_id)
    blocks
  end

  def to_slack_details_blocks(channel_id = nil)
    blocks = []
    blocks << { type: 'section', text: { type: 'plain_text', text: truncated_description, emoji: true } } if description && !description.blank? && display_field?(ActivityFields::DESCRIPTION, channel_id)

    fields_text = slack_fields_s(channel_id)
    effective_maps = team.channel_maps_for(channel_id)
    if map&.polyline? && effective_maps == 'full'
      blocks << { type: 'section', text: { type: 'mrkdwn', text: fields_text } } if fields_text
      blocks << { type: 'image', image_url: map.proxy_image_url, alt_text: '' }
    elsif map&.polyline? && effective_maps == 'thumb' && fields_text
      blocks << { type: 'section', text: { type: 'mrkdwn', text: fields_text }, accessory: { type: 'image', image_url: map.proxy_image_url, alt_text: '' } }
    elsif fields_text
      blocks << { type: 'section', text: { type: 'mrkdwn', text: fields_text } }
    end

    blocks.concat(photos.map(&:to_slack)) if display_field?(ActivityFields::PHOTOS, channel_id) && photos.any?

    blocks
  end

  def to_s
    "id=#{strava_id}, name=#{name}, date=#{start_date_local&.iso8601}, distance=#{distance_s}, moving time=#{moving_time_in_hours_s}, pace=#{pace_s}, #{map}"
  end

  def validate_team
    return if team_id && user.team_id == team_id

    errors.add(:team, 'Activity must belong to the same team as the user.')
  end

  def finished_at
    Time.at(start_date.to_i + elapsed_time.to_i)
  end

  def start_latlng
    map&.start_latlng
  end

  def update_weather!
    return if weather.present?
    return unless start_latlng

    dt = (Time.now - finished_at).to_i

    weather_options = { lat: start_latlng[0], lon: start_latlng[1] }

    if dt > 5.days.to_i
      return # OneCall Api does not return data that old
    elsif dt > 9.hours.to_i
      weather_options.merge!(dt: finished_at, exclude: ['hourly'])
    else
      weather_options.merge!(exclude: %w[minutely hourly daily])
    end

    current_weather = OpenWeather::Client.new.one_call(weather_options).current
    unless current_weather
      logger.warn "Error getting weather at #{start_latlng.join(', ')} on #{finished_at.to_i} for #{user}, #{self}, none returned."
      return
    end

    current_weather.weather.each do |w|
      w.icon_uri = w.icon_uri.to_s
    end

    build_weather(current_weather.to_h)
  rescue StandardError => e
    logger.warn "Error getting weather at #{start_latlng.join(', ')} on #{finished_at.to_i} for #{user}, #{self}, #{e.message}."
  end

  def weather_s(channel_id = nil)
    return unless weather.present?

    current_weather = OpenWeather::Models::OneCall::CurrentWeather.new(
      weather.attributes.except('_id', 'updated_at', 'created_at')
    )

    main = current_weather.weather&.first&.main

    case effective_temperature(channel_id)
    when 'c' then
      ["#{current_weather.temp_c.to_i}°C", main].compact.join(' ')
    when 'f' then
      ["#{current_weather.temp_f.to_i}°F", main].compact.join(' ')
    when 'both' then
      [
        [
          "#{current_weather.temp_f.to_i}°F",
          "#{current_weather.temp_c.to_i}°C"
        ].join(ActivityMethods::UNIT_SEPARATOR),
        main
      ].compact.join(' ')
    end
  end
end
