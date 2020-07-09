class UserActivity < Activity
  field :start_date, type: DateTime
  field :start_date_local, type: DateTime

  belongs_to :user, inverse_of: :activities
  embeds_one :map
  embeds_one :weather

  index(user_id: 1, start_date: 1)
  index('map._id' => 1)

  before_validation :validate_team

  def hidden?
    (private? && !user.private_activities?) ||
      (visibility == 'only_me' && !user.private_activities?) ||
      (visibility == 'followers_only' && !user.followers_only_activities?)
  end

  def start_date_local_s
    return unless start_date_local

    start_date_local.strftime('%A, %B %d, %Y at %I:%M %p')
  end

  def brag!
    return if bragged_at

    if hidden?
      logger.info "Skipping #{user}, #{self}, private."
      update_attributes!(bragged_at: Time.now.utc)
      []
    else
      logger.info "Bragging about #{user}, #{self}."
      rc = user.inform!(to_slack)
      update_attributes!(bragged_at: Time.now.utc, channel_messages: rc)
      rc
    end
  rescue Slack::Web::Api::Errors::SlackError => e
    case e.message
    when 'not_in_channel', 'account_inactive' then
      logger.warn "Bragging to #{user} failed, #{e.message}."
      NewRelic::Agent.notice_error(e, custom_params: { team: user.team.to_s, self: user.to_s })
      nil
    else
      raise e
    end
  end

  def rebrag!
    return unless channel_messages

    logger.info "Rebragging about #{user}, #{self}."
    rc = user.update!(to_slack, channel_messages)
    update_attributes!(channel_messages: rc)
    rc
  end

  def attrs_from_strava(response)
    Activity.attrs_from_strava(response).merge(
      start_date: response.start_date,
      start_date_local: response.start_date_local
    )
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

  def to_slack_attachment
    result = {}
    result[:fallback] = "#{name} via #{user.slack_mention}, #{distance_s} #{moving_time_in_hours_s} #{pace_s}"
    result[:title] = name
    result[:title_link] = strava_url
    result[:text] = ["<@#{user.user_name}> on #{start_date_local_s}", description].compact.join("\n\n")
    if map
      if team.maps == 'full'
        result[:image_url] = map.proxy_image_url(user.team.maps_format)
      elsif team.maps == 'thumb'
        result[:thumb_url] = map.proxy_image_url(user.team.maps_format)
      end
    end
    result[:fields] = slack_fields
    result.merge!(user.athlete.to_slack) if user.athlete
    result
  end

  def to_s
    "name=#{name}, date=#{start_date_local_s}, distance=#{distance_s}, moving time=#{moving_time_in_hours_s}, pace=#{pace_s}, #{map}"
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
    current_weather.weather.each do |w|
      w.icon_uri = w.icon_uri.to_s
    end

    build_weather(current_weather.to_h) if current_weather
  rescue StandardError => e
    logger.warn "Error getting weather at #{start_latlng.join(', ')} on #{finished_at.to_i} for #{user}, #{self}, #{e.message}."
  end

  def weather_s
    return unless weather.present?

    current_weather = OpenWeather::Models::OneCall::CurrentWeather.new(
      weather.attributes.except('_id', 'updated_at', 'created_at')
    )

    main = current_weather.weather&.first&.main

    case team.units
    when 'km' then
      ["#{current_weather.temp_c.to_i}°C", main].compact.join(' ')
    when 'mi' then
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
