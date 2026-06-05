class Club
  include Mongoid::Document

  DEPRECATION_MESSAGE = 'Strava is removing the Club Activities API on September 1, 2026. ' \
                        'All club functionality will be removed before that deadline. ' \
                        'Please ask your team members to connect individually by DMing me `connect`. ' \
                        'See https://github.com/dblock/slack-strava/issues/264 for details.'.freeze

  SYNC_DISABLED_MESSAGE = 'Club activity syncing has been disabled. ' \
                          'Strava is removing the Club Activities API on September 1, 2026 and all club ' \
                          'functionality will be removed before that deadline. ' \
                          'Please ask your team members to connect individually by DMing me `connect`. ' \
                          'See https://github.com/dblock/slack-strava/issues/264 for details.'.freeze

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
  field :locking_name, type: String
  field :locked_at, type: Time

  belongs_to :team
  validates_presence_of :team_id

  field :channel_id, type: String
  field :channel_name, type: String

  field :deprecation_informed_at, type: DateTime
  field :sync_disabled_informed_at, type: DateTime

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
    activity = activities.not_bragged.where(first_sync: false).asc(:_id).first
    return unless activity

    results = activity.brag!
    return unless results&.any?

    results.map do |result|
      result.merge(activity: activity)
    end
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

  def sync_and_brag!
    with_lock do
      with_strava_error_handler do
        brag!
      end
    end
    inform_sync_disabled!
  end

  private

  def dm!(message)
    message_with_channel = to_slack.merge(text: message, channel: channel_id, as_user: true)
    logger.info "Posting '#{message_with_channel.to_json}' to #{team} on ##{channel_name}."
    team.slack_client.chat_postMessage(message_with_channel)
  end

  def inform_sync_disabled!
    return if sync_disabled_informed_at

    dm! Club::SYNC_DISABLED_MESSAGE unless team.clubs.where(channel_id: channel_id, :sync_disabled_informed_at.ne => nil).exists?
    update_attributes!(sync_disabled_informed_at: Time.now.utc)
  rescue Slack::Web::Api::Errors::SlackError => e
    logger.warn "Failed to send sync disabled notice to #{self}: #{e.message}."
  end
end
