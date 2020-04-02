class ClubActivity < Activity
  field :athlete_name, type: String

  belongs_to :club, inverse_of: :activities

  index(club_id: 1)

  before_validation :validate_team

  def brag!
    if bragged_at?
      logger.info "Already bragged about #{club}, #{self}"
      nil
    elsif bragged_in?(club.channel_id)
      update_attributes!(bragged_at: Time.now.utc)
      logger.info "Already bragged about #{club} in #{club.channel_id}, #{self}"
      nil
    else
      logger.info "Bragging about #{club}, #{self}"
      message_with_channel = to_slack.merge(channel: club.channel_id, as_user: true)
      logger.info "Posting '#{message_with_channel.to_json}' to #{club.team} on ##{club.channel_name}."
      channel_message = club.team.slack_client.chat_postMessage(message_with_channel)
      if channel_message
        channel_message = { ts: channel_message['ts'], channel: club.channel_id }
      end
      update_attributes!(bragged_at: Time.now.utc, channel_messages: [channel_message])
      [channel_message]
    end
  rescue Slack::Web::Api::Errors::SlackError => e
    case e.message
    when 'not_in_channel', 'account_inactive' then
      logger.warn "Bragging to #{club} failed, #{e.message}."
      nil
    else
      raise e
    end
  end

  def self.attrs_from_strava(response)
    Activity.attrs_from_strava(response).merge(
      strava_id: Digest::MD5.hexdigest(response.to_s),
      athlete_name: [response.athlete.firstname, response.athlete.lastname].compact.join(' '),
      average_speed: response.moving_time.positive? ? response.distance / response.moving_time : 0
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

  def validate_team
    return if team_id && club.team_id == team_id

    errors.add(:team, 'Activity must belong to the same team as the club.')
  end
end
