class ClubActivity < Activity
  field :athlete_name, type: String
  field :fetched_at, type: DateTime
  field :first_sync, type: Boolean, default: false

  belongs_to :club, inverse_of: :activities

  index(club_id: 1, first_sync: 1)

  before_validation :validate_team

  def brag!
    if bragged_at?
      logger.info "Already bragged about #{club}, #{self}"
      nil
    elsif first_sync?
      update_attributes!(bragged_at: Time.now.utc)
      logger.info "Skipping first sync about #{club} in #{club.channel_id}, #{self}"
      nil
    elsif bragged_in?(club.channel_id)
      update_attributes!(bragged_at: Time.now.utc)
      logger.info "Already bragged about #{club} in #{club.channel_id}, #{self}"
      nil
    elsif privately_bragged?
      update_attributes!(bragged_at: Time.now.utc)
      logger.info "Found a privately bragged activity about #{club} in #{club.channel_id}, #{self}"
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
    when 'is_archived'
      logger.warn "Bragging to #{club} failed, #{e.message}."
      club.team.inform_admin!(text: "I couldn't post an activity from #{club.name} into #{club.channel_mention} because the channel was archived, please reconnect that club in a different channel.")
      club.update_attributes!(sync_activities: false)
      NewRelic::Agent.notice_error(e, custom_params: { team: club.team.to_s, self: club.to_s })
      nil
    when 'restricted_action'
      logger.warn "Bragging to #{club} failed, #{e.message}."
      club.team.inform_admin!(text: "I wasn't allowed to post into #{club.channel_mention} because of a Slack workspace preference, please contact your Slack admin.")
      NewRelic::Agent.notice_error(e, custom_params: { team: club.team.to_s, self: club.to_s })
      nil
    when 'not_in_channel', 'account_inactive'
      logger.warn "Bragging to #{club} failed, #{e.message}."
      NewRelic::Agent.notice_error(e, custom_params: { team: club.team.to_s, self: club.to_s })
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

  def to_slack
    attachment = {}
    attachment[:fallback] = "#{name} by #{athlete_name} via #{club.name}, #{distance_s} #{moving_time_in_hours_s} #{pace_s}"
    attachment[:title] = name
    attachment[:title_link] = club.strava_url
    attachment[:text] = "#{athlete_name}, #{club.name}"
    fields = slack_fields
    attachment[:fields] = fields if fields
    attachment[:thumb_url] = club.logo

    {
      attachments: [
        attachment
      ]
    }
  end

  def validate_team
    return if team_id && club.team_id == team_id

    errors.add(:team, 'Activity must belong to the same team as the club.')
  end
end
