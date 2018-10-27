class ClubActivity < Activity
  field :athlete_name, type: String

  belongs_to :club, inverse_of: :activities

  index(club_id: 1)

  def team
    club.team
  end

  def brag!
    return if bragged_at
    logger.info "Bragging about #{club}, #{self}"
    message_with_channel = to_slack.merge(channel: club.channel_id, as_user: true)
    logger.info "Posting '#{message_with_channel.to_json}' to #{club.team} on ##{club.channel_name}."
    channel_message = club.team.slack_client.chat_postMessage(message_with_channel)
    channel_message = { ts: channel_message['ts'], channel: club.channel_id } if channel_message
    update_attributes!(bragged_at: Time.now.utc, channel_messages: [channel_message])
    [channel_message]
  rescue Slack::Web::Api::Errors::SlackError => e
    case e.message
    when 'not_in_channel' then
      logger.error "Bragging to #{club} failed, removed from channel, destroying."
      club.destroy
      nil
    else
      raise e
    end
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
    fields = slack_fields
    result[:fields] = fields if fields
    result[:thumb_url] = club.logo
    result
  end
end
