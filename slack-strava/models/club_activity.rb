class ClubActivity < Activity
  field :athlete_name, type: String

  belongs_to :club, inverse_of: :activities

  index(club_id: 1)

  def team
    club.team
  end

  def brag!
    return if bragged_at
    Api::Middleware.logger.info "Bragging about #{club}, #{self}"
    message_with_channel = to_slack.merge(channel: club.channel_id, as_user: true)
    Api::Middleware.logger.info "Posting '#{message_with_channel.to_json}' to #{club.team} on ##{club.channel_name}."
    rc = club.team.slack_client.chat_postMessage(message_with_channel)
    update_attributes!(bragged_at: Time.now.utc)
    {
      ts: rc['ts'],
      channel: club.channel_id
    }
  end

  def self.attrs_from_strava(response)
    Activity.attrs_from_strava(response).merge(
      strava_id: Digest::MD5.hexdigest(response.to_s),
      athlete_name: [response['athlete']['firstname'], response['athlete']['lastname']].compact.join(' '),
      average_speed: response['moving_time'].positive? ? response['distance'] / response['moving_time'] : 0
    )
  end

  def to_slack_attachment
    result = {}
    result[:fallback] = "#{name} by #{athlete_name} via #{club.name}, #{distance_s} #{moving_time_in_hours_s} #{pace_s}"
    result[:title] = name
    result[:title_link] = club.strava_url
    result[:text] = "#{athlete_name}, #{club.name}"
    result[:fields] = slack_fields
    result[:thumb_url] = club.logo
    result
  end
end
