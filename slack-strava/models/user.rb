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

  has_many :activities, dependent: :destroy

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
    query = user_name =~ /^<@(.*)>$/ ? { user_id: Regexp.last_match[1] } : { user_name: Regexp.new("^#{user_name}$", 'i') }
    user = User.where(query.merge(team: team)).first
    raise SlackStrava::Error, "I don't know who #{user_name} is!" unless user
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

  def to_s
    "user_id=#{user_id}, user_name=#{user_name}"
  end

  def connect!(code)
    response = Strava::Api::V3::Auth.retrieve_access(ENV['STRAVA_CLIENT_ID'], ENV['STRAVA_CLIENT_SECRET'], code)
    raise "Strava returned #{response.code}: #{response.body}" unless response.success?
    create_athlete(athlete_id: response['athlete']['id'])
    update_attributes!(token_type: response['token_type'], access_token: response['access_token'])
    Api::Middleware.logger.info "Connected team=#{team_id}, user=#{user_name}, user_id=#{id}, athlete_id=#{athlete.athlete_id}"
    sync_last_strava_activity!
    dm!(text: 'Your Strava account has been successfully connected.')
  end

  def dm!(message)
    client = Slack::Web::Client.new(token: team.token)
    im = client.im_open(user: user_id)
    client.chat_postMessage(message.merge(channel: im['channel']['id'], as_user: true))
  end

  def brag!
    activity = activities.unbragged.asc(:start_date).first
    return unless activity
    [activity, activity.brag!]
  end

  def sync_last_strava_activity!
    raise 'Missing access_token' unless access_token
    client = Strava::Api::V3::Client.new(access_token: access_token)
    activities = client.list_athlete_activities(per_page: 1)
    return unless activities.any?
    Activity.create_from_strava!(self, activities.first)
  end

  def sync_new_strava_activities!
    dt = DateTime.now.utc
    sync_strava_activities!(after: activities_at || created_at)
    update_attributes!(activities_at: dt)
  end

  private

  def sync_strava_activities!(options = {})
    raise 'Missing access_token' unless access_token
    client = Strava::Api::V3::Client.new(access_token: access_token)
    page = 1
    page_size = 10
    loop do
      activities = client.list_athlete_activities(options.merge(page: page, per_page: page_size))
      activities.each do |activity|
        Activity.create_from_strava!(self, activity)
      end
      break if activities.size < page_size
      page += 1
    end
  end
end
