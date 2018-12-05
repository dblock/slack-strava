class UserActivity < Activity
  field :start_date, type: DateTime
  field :start_date_local, type: DateTime

  belongs_to :user, inverse_of: :activities
  embeds_one :map

  index(user_id: 1, start_date: 1)

  def team
    user.team
  end

  def start_date_local_s
    return unless start_date_local
    start_date_local.strftime('%A, %B %d, %Y at %I:%M %p')
  end

  def brag!
    return if bragged_at
    logger.info "Bragging about #{user}, #{self}"
    rc = user.inform!(to_slack)
    update_attributes!(bragged_at: Time.now.utc, channel_messages: rc)
    rc
  end

  def rebrag!
    return unless channel_messages
    logger.info "Rebragging about #{user}, #{self}"
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
    activity = UserActivity.where(strava_id: response.id, user_id: user.id).first
    activity ||= UserActivity.new(strava_id: response.id, user_id: user.id)
    activity.update_from_strava(response)
    return unless activity.changed?
    activity.map.update!
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
        result[:image_url] = map.proxy_image_url
      elsif team.maps == 'thumb'
        result[:thumb_url] = map.proxy_image_url
      end
    end
    result[:fields] = slack_fields
    result.merge!(user.athlete.to_slack) if user.athlete
    result
  end

  def to_s
    "name=#{name}, date=#{start_date_local_s}, distance=#{distance_s}, moving time=#{moving_time_in_hours_s}, pace=#{pace_s}, #{map}"
  end
end
