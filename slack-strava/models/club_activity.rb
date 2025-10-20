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
      thread_ts = parent_thread(club.channel_id)
      message_with_channel[:thread_ts] = thread_ts if thread_ts
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
      club.update_attributes!(sync_activities: false)
      club.team.inform_admin!(text: "I couldn't post an activity from #{club.name} into #{club.channel_mention} because the channel was archived, please reconnect that club in a different channel.")
      NewRelic::Agent.notice_error(e, custom_params: { team: club.team.to_s, club: club.to_s, activity: to_s })
      nil
    when 'restricted_action'
      logger.warn "Bragging to #{club} failed, #{e.message}."
      club.update_attributes!(sync_activities: false)
      club.team.inform_admin!(text: "I wasn't allowed to post into #{club.channel_mention} because of a Slack workspace preference, please contact your Slack admin.")
      NewRelic::Agent.notice_error(e, custom_params: { team: club.team.to_s, club: club.to_s, activity: to_s })
      nil
    when 'not_in_channel', 'account_inactive'
      logger.warn "Bragging to #{club} failed, #{e.message}."
      club.update_attributes!(sync_activities: false)
      NewRelic::Agent.notice_error(e, custom_params: { team: club.team.to_s, club: club.to_s, activity: to_s })
      nil
    else
      raise e
    end
  end

  # backwards compatible hash to strava-ruby-client 2.x
  def self.response_hash(response)
    Digest::MD5.hexdigest([
      '#<Strava::Models::Activity',
      "athlete=#<Strava::Models::Athlete firstname=\"#{response.athlete.firstname}\" lastname=\"#{response.athlete.lastname}\" resource_state=#{response.athlete.resource_state}>",
      "distance=#{response.distance}",
      "elapsed_time=#{response.elapsed_time}",
      "moving_time=#{response.moving_time}",
      "name=\"#{response.name}\"",
      "resource_state=#{response.resource_state}",
      "total_elevation_gain=#{response.total_elevation_gain}",
      "workout_type=#{response.workout_type}>"
    ].join(' '))
  end

  def self.attrs_from_strava(response)
    {
      strava_id: response_hash(response),
      name: response.name,
      distance: response.distance,
      moving_time: response.moving_time,
      elapsed_time: response.elapsed_time,
      type: response.sport_type,
      total_elevation_gain: response.total_elevation_gain,
      athlete_name: [response.athlete.firstname, response.athlete.lastname].compact.join(' '),
      average_speed: response.moving_time.positive? ? response.distance / response.moving_time : 0
    }
  end

  def display_context_s
    ary = [
      athlete_name,
      club.name
    ].compact

    ary.any? ? ary.join(' on ') : nil
  end

  def to_slack
    {
      blocks: to_slack_blocks,
      attachments: []
    }
  end

  def to_slack_blocks
    blocks = []
    blocks << { type: 'section', text: { type: 'mrkdwn', text: "*<#{club.strava_url}|#{name || strava_id}>*" } }
    blocks << {
      type: 'context',
      elements: [
        { type: 'mrkdwn', text: "#{athlete_name} via #{club.name}" }
      ]
    }
    slack_fields_text = slack_fields_s
    blocks << { type: 'section', text: { type: 'mrkdwn', text: slack_fields_text }, accessory: { type: 'image', image_url: club.logo, alt_text: club.name.to_s } } if slack_fields_text
    blocks
  end

  def validate_team
    return if team_id && club.team_id == team_id

    errors.add(:team, 'Activity must belong to the same team as the club.')
  end
end
