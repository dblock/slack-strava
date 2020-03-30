class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include StravaTokens
  include Brag

  field :user_id, type: String
  field :user_name, type: String
  field :activities_at, type: DateTime
  field :connected_to_strava_at, type: DateTime
  field :is_bot, type: Boolean, default: false
  field :is_owner, type: Boolean, default: false
  field :is_admin, type: Boolean, default: false
  field :private_activities, type: Boolean, default: false
  field :sync_activities, type: Boolean, default: true

  embeds_one :athlete
  index('athlete.athlete_id' => 1)

  belongs_to :team, index: true
  validates_presence_of :team

  has_many :activities, class_name: 'UserActivity', dependent: :destroy

  index({ user_id: 1, team_id: 1 }, unique: true)
  index(user_name: 1, team_id: 1)

  scope :connected_to_strava, -> { where(:access_token.ne => nil) }

  after_update :connected_to_strava_changed
  after_update :sync_activities_changed

  def connected_to_strava?
    !access_token.nil?
  end

  def connect_to_strava_url
    redirect_uri = "#{SlackRubyBotServer::Service.url}/connect"
    "https://www.strava.com/oauth/authorize?client_id=#{ENV['STRAVA_CLIENT_ID']}&redirect_uri=#{redirect_uri}&response_type=code&scope=activity:read_all&state=#{id}"
  end

  def slack_mention
    "<@#{user_id}>"
  end

  def self.find_by_slack_mention!(team, user_name)
    query = user_name =~ /^<@(.*)>$/ ? { user_id: ::Regexp.last_match[1] } : { user_name: ::Regexp.new("^#{user_name}$", 'i') }
    user = User.where(query.merge(team: team)).first
    raise SlackStrava::Error, "I don't know who #{user_name} is!" unless user

    user
  end

  def self.find_create_or_update_by_team_and_slack_id!(team_id, user_id)
    team = Team.where(team_id: team_id).first || raise("Cannot find team ID #{team_id}")
    user = User.where(team: team, user_id: user_id).first || User.create!(team: team, user_id: user_id)
    user
  end

  # Find an existing record, update the username if necessary, otherwise create a user record.
  def self.find_create_or_update_by_slack_id!(client, slack_id)
    instance = User.where(team: client.owner, user_id: slack_id).first
    instance_info = Hashie::Mash.new(client.web_client.users_info(user: slack_id)).user
    if instance && (instance.user_name != instance_info.name || instance.is_bot != instance_info.is_bot || instance.is_admin != instance_info.is_admin || instance.is_owner != instance_info.is_owner)
      instance.update_attributes!(user_name: instance_info.name, is_bot: instance_info.is_bot, is_admin: instance_info.is_admin, is_owner: instance_info.is_owner)
    end
    instance ||= User.create!(team: client.owner, user_id: slack_id, user_name: instance_info.name, is_bot: instance_info.is_bot)
    instance
  end

  def inform!(message)
    team.slack_channels.map { |channel|
      next if user_id && !user_in_channel?(channel['id'])

      message_with_channel = message.merge(channel: channel['id'], as_user: true)
      logger.info "Posting '#{message_with_channel.to_json}' to #{team} on ##{channel['name']}."
      rc = team.slack_client.chat_postMessage(message_with_channel)

      {
        ts: rc['ts'],
        channel: channel['id']
      }
    }.compact
  end

  def update!(message, channel_messages)
    channel_messages.map { |channel_message|
      message_with_channel = message.merge(channel: channel_message.channel, ts: channel_message.ts, as_user: true)
      logger.info "Updating '#{message_with_channel.to_json}' to #{team} on ##{channel_message.channel}."
      rc = team.slack_client.chat_update(message_with_channel)

      {
        ts: rc['ts'],
        channel: channel_message.channel
      }
    }.compact
  end

  def to_s
    "user_id=#{user_id}, user_name=#{user_name}"
  end

  def connect!(code)
    response = get_access_token!(code)
    logger.debug "Connecting team=#{team_id}, user=#{user_name}, user_id=#{id}, #{response}"
    raise 'Missing access_token in OAuth response.' unless response.access_token
    unless response.refresh_token
      raise 'Missing refresh_token in OAuth response.'
    end
    raise 'Missing expires_at in OAuth response.' unless response.expires_at

    create_athlete(Athlete.attrs_from_strava(response.athlete))
    update_attributes!(
      token_type: response.token_type,
      access_token: response.access_token,
      refresh_token: response.refresh_token,
      token_expires_at: Time.at(response.expires_at),
      connected_to_strava_at: DateTime.now.utc
    )
    logger.info "Connected team=#{team_id}, user=#{user_name}, user_id=#{id}, athlete_id=#{athlete.athlete_id}"
    dm!(text: "Your Strava account has been successfully connected.\nI won't post any private activities, DM me `set private on` to toggle that and `help` for other options.")
    inform!(text: "New Strava account connected for #{slack_mention}.")
  end

  def disconnect_from_strava
    if access_token
      logger.info "Disconnected team=#{team_id}, user=#{user_name}, user_id=#{id}"
      reset_access_tokens!(connected_to_strava_at: nil)
      { text: 'Your Strava account has been successfully disconnected.' }
    else
      { text: 'Your Strava account is not connected.' }
    end
  end

  def disconnect!
    dm!(disconnect_from_strava)
  end

  def connect_to_strava(message = 'Please connect your Strava account')
    url = connect_to_strava_url
    {
      text: "#{message}.", attachments: [
        fallback: "#{message} at #{url}.",
        actions: [
          type: 'button',
          text: 'Click Here',
          url: url
        ]
      ]
    }
  end

  def dm_connect!(message = 'Please connect your Strava account')
    dm!(connect_to_strava(message))
  end

  def dm!(message)
    im = team.slack_client.im_open(user: user_id)
    team.slack_client.chat_postMessage(message.merge(channel: im['channel']['id'], as_user: true))
  end

  def brag!
    brag_new_activities!
  end

  def rebrag!
    with_strava_error_handler do
      rebrag_last_activity!
    end
  end

  def brag_new_activities!
    activity = activities.unbragged.asc(:start_date).first
    return unless activity

    update_attributes!(activities_at: activity.start_date)
    results = activity.brag!
    return unless results

    results.map do |result|
      result.merge(activity: activity)
    end
  end

  # updates activity details, brings in description, etc.
  def rebrag_last_activity!
    activity = latest_bragged_activity
    return unless activity

    detailed_activity = strava_client.activity(activity.strava_id)
    return if detailed_activity['private'] && !private_activities?

    activity = UserActivity.create_from_strava!(self, detailed_activity)
    return unless activity

    results = activity.rebrag!
    return unless results

    results.map do |result|
      result.merge(activity: activity)
    end
  end

  def sync_new_strava_activities!
    dt = activities_at || latest_activity_start_date || connected_to_strava_at || created_at
    options = {}
    options[:after] = dt.to_i unless dt.nil?
    sync_strava_activities!(options)
  end

  def sync_strava_activity!(strava_id)
    detailed_activity = strava_client.activity(strava_id)
    return if detailed_activity['private'] && !private_activities?
    if detailed_activity.athlete.id.to_s != athlete.athlete_id
      raise 'Activity athlete ID do not match.'
    end

    UserActivity.create_from_strava!(self, detailed_activity) || activities.where(strava_id: detailed_activity.id).first
  rescue Strava::Errors::Fault => e
    handle_strava_error e
  end

  def athlete_clubs_to_slack(channel_id)
    result = { text: '', channel: channel_id, attachments: [] }
    clubs = team.clubs.where(channel_id: channel_id).to_a
    if connected_to_strava?
      strava_client.athlete_clubs do |row|
        strava_id = row.id.to_s
        next if clubs.detect { |club| club.strava_id == strava_id }

        clubs << Club.new(Club.attrs_from_strava(row).merge(team: team))
      end
    end
    clubs.sort_by(&:strava_id).each do |club|
      result[:attachments].concat(club.connect_to_slack[:attachments])
    end
    result[:text] = 'Not connected to any clubs.' if result[:attachments].empty?
    result
  end

  def activated_user?
    team.activated_user_id && team.activated_user_id == user_id
  end

  def team_admin?
    activated_user? || is_admin? || is_owner?
  end

  private

  def latest_bragged_activity(dt = 12.hours)
    activities.bragged.where(:start_date.gt => Time.now - dt).desc(:start_date).first
  end

  def latest_activity_start_date
    activities.desc(:start_date).first&.start_date
  end

  def user_in_channel?(channel_id)
    team.slack_client.conversations_members(channel: channel_id) do |response|
      return true if response.members.include?(user_id)
    end
    false
  end

  def sync_strava_activities!(options = {})
    return unless sync_activities?

    strava_client.athlete_activities(options) do |activity|
      next if activity.private && !private_activities?

      UserActivity.create_from_strava!(self, activity)
    end
  rescue Strava::Errors::Fault => e
    handle_strava_error e
  end

  def handle_strava_error(e)
    logger.error e
    case e.message
    when /Authorization Error/
      dm_connect! 'There was an authorization problem. Please reconnect your Strava account'
      reset_access_tokens!(connected_to_strava_at: nil)
    end
    raise e
  end

  def connected_to_strava_changed
    return unless connected_to_strava_at? && connected_to_strava_at_changed?

    activities.destroy_all
    set activities_at: nil
  end

  def sync_activities_changed
    return unless sync_activities? && sync_activities_changed?

    activities.destroy_all
    set activities_at: Time.now.utc
  end
end
