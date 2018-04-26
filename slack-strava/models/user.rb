class User
  include Mongoid::Document
  include Mongoid::Timestamps

  field :user_id, type: String
  field :user_name, type: String
  field :access_token, type: String
  field :token_type, type: String
  field :activities_at, type: DateTime
  field :is_bot, type: Boolean

  embeds_one :athlete

  belongs_to :team, index: true
  validates_presence_of :team

  has_many :activities, class_name: 'UserActivity', dependent: :destroy

  index({ user_id: 1, team_id: 1 }, unique: true)
  index(user_name: 1, team_id: 1)

  scope :connected_to_strava, -> { where(:access_token.ne => nil) }

  def connected_to_strava?
    !access_token.nil?
  end

  def connect_to_strava_url
    redirect_uri = "#{SlackStrava::Service.url}/connect"
    "https://www.strava.com/oauth/authorize?client_id=#{ENV['STRAVA_CLIENT_ID']}&redirect_uri=#{redirect_uri}&response_type=code&scope=view_private&state=#{id}"
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
    instance.update_attributes!(user_name: instance_info.name, is_bot: instance_info.is_bot) if instance && (instance.user_name != instance_info.name || instance.is_bot != instance_info.is_bot)
    instance ||= User.create!(team: client.owner, user_id: slack_id, user_name: instance_info.name, is_bot: instance_info.is_bot)
    instance
  end

  def inform!(message)
    team.slack_channels.map { |channel|
      next if user_id && !user_in_channel?(channel['id'])
      message_with_channel = message.merge(channel: channel['id'], as_user: true)
      Api::Middleware.logger.info "Posting '#{message_with_channel.to_json}' to #{team} on ##{channel['name']}."
      rc = team.slack_client.chat_postMessage(message_with_channel)

      {
        ts: rc['ts'],
        channel: channel
      }
    }.compact
  end

  def to_s
    "user_id=#{user_id}, user_name=#{user_name}"
  end

  def connect!(code)
    response = Strava::Api::V3::Auth.retrieve_access(ENV['STRAVA_CLIENT_ID'], ENV['STRAVA_CLIENT_SECRET'], code)
    raise "Strava returned #{response.code}: #{response.body}" unless response.success?
    create_athlete(Athlete.attrs_from_strava(response['athlete']))
    update_attributes!(token_type: response['token_type'], access_token: response['access_token'])
    Api::Middleware.logger.info "Connected team=#{team_id}, user=#{user_name}, user_id=#{id}, athlete_id=#{athlete.athlete_id}"
    sync_last_strava_activity!
    dm!(text: 'Your Strava account has been successfully connected.')
  end

  def disconnect!
    if access_token
      Api::Middleware.logger.info "Disconnected team=#{team_id}, user=#{user_name}, user_id=#{id}"
      update_attributes!(token_type: nil, access_token: nil)
      dm!(text: 'Your Strava account has been successfully disconnected.')
    else
      dm!(text: 'Your Strava account is not connected.')
    end
  end

  def dm_connect!(message = 'Please connect your Strava account')
    url = connect_to_strava_url
    dm!(
      text: "#{message}.", attachments: [
        fallback: "#{message} at #{url}.",
        actions: [
          type: 'button',
          text: 'Click Here',
          url: url
        ]
      ]
    )
  end

  def dm!(message)
    im = team.slack_client.im_open(user: user_id)
    team.slack_client.chat_postMessage(message.merge(channel: im['channel']['id'], as_user: true))
  end

  def brag!
    activity = activities.unbragged.asc(:start_date).first
    return unless activity
    update_attributes!(activities_at: activity.start_date)
    results = activity.brag!
    return unless results
    results.map do |result|
      result.merge(activity: activity)
    end
  end

  def strava_client
    raise 'Missing access_token' unless access_token
    @strava_client ||= Strava::Api::V3::Client.new(access_token: access_token)
  end

  def sync_last_strava_activity!
    activities = strava_client.list_athlete_activities(per_page: 1)
    return unless activities.any?
    Api::Middleware.logger.debug "Activity team=#{team_id}, user=#{user_name}, #{activities.first}"
    UserActivity.create_from_strava!(self, activities.first)
  rescue Strava::Api::V3::ClientError => e
    handle_strava_error e
  end

  def sync_new_strava_activities!
    sync_strava_activities!(after: activities_at || created_at)
  end

  def athlete_clubs_to_slack(channel_id)
    result = { text: '', channel: channel_id, attachments: [] }
    clubs = team.clubs.where(channel_id: channel_id).to_a
    if connected_to_strava?
      strava_client.paginate(:list_athlete_clubs) do |row|
        strava_id = row['id'].to_s
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

  private

  def user_in_channel?(channel_id)
    team.slack_client.conversations_members(channel: channel_id) do |response|
      return true if response.members.include?(user_id)
    end
    false
  end

  def sync_strava_activities!(options = {})
    strava_client.paginate(:list_athlete_activities, options) do |activity|
      UserActivity.create_from_strava!(self, activity)
    end
  rescue Strava::Api::V3::ClientError => e
    handle_strava_error e
  end

  def handle_strava_error(e)
    Api::Middleware.logger.error e
    case e.message
    when '{"message":"Authorization Error","errors":[{"resource":"Athlete","field":"access_token","code":"invalid"}]} [HTTP 401]' then
      dm_connect! 'There was an authorization problem. Please reconnect your Strava account'
      update_attributes!(access_token: nil)
    end
    raise e
  end
end
