class Club
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Locker
  include StravaTokens
  include Brag

  field :strava_id, type: String
  field :name, type: String
  field :description, type: String
  field :logo, type: String
  field :sport_type, type: String
  field :city, type: String
  field :state, type: String
  field :country, type: String
  field :url, type: String
  field :member_count, type: Integer
  field :sync_activities, type: Boolean, default: true
  field :first_sync_at, type: DateTime
  field :locking_name, type: String
  field :locked_at, type: Time

  belongs_to :team
  validates_presence_of :team_id

  field :channel_id, type: String
  field :channel_name, type: String

  index({ team_id: 1, strava_id: 1, channel_id: 1 }, unique: true)

  has_many :activities, class_name: 'ClubActivity', dependent: :destroy

  scope :connected_to_strava, -> { where(:access_token.ne => nil, sync_activities: true) }

  def to_s
    "strava_id=#{strava_id}, name=#{name}, url=#{strava_url}, channel_id=#{channel_id}, channel_name=#{channel_name}, #{team}"
  end

  def strava_url
    "https://www.strava.com/clubs/#{url}"
  end

  def brag!
    activity = activities.unbragged.where(first_sync: false).asc(:_id).first
    return unless activity

    results = activity.brag!
    return unless results&.any?

    results.map do |result|
      result.merge(activity: activity)
    end
  end

  def self.detailed_attrs_from_strava(response)
    {
      strava_id: response.id,
      name: response.name,
      description: response.description,
      logo: response.profile_medium,
      sport_type: response.sport_type,
      city: response.city && !response.city.empty? ? response.city : nil,
      state: response.state && !response.state.empty? ? response.state : nil,
      country: response.country && !response.country.empty? ? response.country : nil,
      url: response.url,
      member_count: response.member_count
    }
  end

  def self.summary_attrs_from_strava(response)
    {
      strava_id: response.id,
      name: response.name,
      sport_type: response.sport_type,
      city: response.city && !response.city.empty? ? response.city : nil,
      state: response.state && !response.state.empty? ? response.state : nil,
      country: response.country && !response.country.empty? ? response.country : nil,
      url: response.url,
      member_count: response.member_count
    }
  end

  def member_count_s
    if member_count > 1
      "#{member_count} members"
    elsif member_count == 1
      '1 member'
    end
  end

  def location
    [city, state, country].compact.join(', ')
  end

  def channel_mention
    "<##{channel_id}>"
  end

  def disabled_s
    return unless persisted? && !sync_activities?

    'Sync disabled.'
  end

  def to_slack
    {
      attachments: [{
        title: name,
        title_link: strava_url,
        text: [description, location, member_count_s, disabled_s].compact.join("\n"),
        thumb_url: logo,
        color: '#FC4C02'
      }]
    }
  end

  def connect_to_slack
    {
      attachments: [{
        title: name,
        title_link: strava_url,
        text: [description, location, member_count_s, disabled_s].compact.join("\n"),
        thumb_url: logo,
        color: '#FC4C02',
        callback_id: "club-#{persisted? && sync_activities? ? 'disconnect' : 'connect'}-channel",
        actions: [{
          name: 'strava_id',
          text: persisted? && sync_activities? ? 'Disconnect' : 'Connect',
          type: 'button',
          value: strava_id
        }]
      }]
    }
  end

  def sync_last_strava_activity!
    sync_strava_activities!(page: 1, per_page: 1, limit: 1)
  end

  def sync_new_strava_activities!
    sync_strava_activities!(per_page: 10, limit: 50)
    update_attributes!(first_sync_at: Time.now.utc) unless first_sync_at
  end

  private

  def sync_strava_activities!(options = {})
    return unless sync_activities?

    strava_client.club_activities(strava_id, options).map do |activity|
      club_activity = ClubActivity.new(
        ClubActivity.attrs_from_strava(activity).merge(
          team: team, club: self, fetched_at: Time.now.utc, first_sync: first_sync_at.nil?
        )
      )

      existing_activity = ClubActivity.where(strava_id: club_activity.strava_id, club: self).first
      if existing_activity
        # still fetching this activity, prevent the activity from being purged by a 30 day TTL index
        existing_activity.update_attributes!(fetched_at: Time.now.utc)
        next
      end

      club_activity.save!
      logger.debug "Activity #{self}, team_id=#{team_id}, #{club_activity}"
      club_activity
    end
  rescue Slack::Web::Api::Errors::NotInChannel => e
    handle_slack_error e
  rescue Faraday::ResourceNotFound => e
    handle_not_found_error e
  rescue Strava::Errors::Fault => e
    handle_strava_error e
  end

  def dm!(message)
    message_with_channel = to_slack.merge(text: message, channel: channel_id, as_user: true)
    logger.info "Posting '#{message_with_channel.to_json}' to #{team} on ##{channel_name}."
    team.slack_client.chat_postMessage(message_with_channel)
  end

  def handle_not_found_error(e)
    set sync_activities: false
    logger.error e
    dm! 'Your club can no longer be found on Strava. Please disconnect and reconnect it via /slava clubs.'
    raise e
  end

  def handle_slack_error(e)
    set sync_activities: false
    logger.error e
    raise e
  end

  def handle_strava_error(e)
    logger.error e
    case e.message
    when 'Forbidden', 'Authorization Error'
      reset_access_tokens!
      dm! 'There was an authorization problem. Please reconnect the club via /slava clubs.'
    when 'Bad Request'
      error = e.errors&.first
      code = error && error['code']
      if code == 'invalid'
        reset_access_tokens!
        dm! 'There was an authorization problem refreshing the club access token. Please reconnect the club via /slava clubs.'
      end
    end
    raise e
  end
end
