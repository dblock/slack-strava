class User
  include Mongoid::Document
  include Mongoid::Timestamps

  field :user_id, type: String
  field :user_name, type: String
  field :access_token, type: String
  field :token_type, type: String
  field :activities_at, type: DateTime

  embeds_one :athlete

  belongs_to :team, index: true
  validates_presence_of :team

  has_many :activities, dependent: :destroy

  index({ user_id: 1, team_id: 1 }, unique: true)
  index(user_name: 1, team_id: 1)

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
    instance.update_attributes!(user_name: instance_info.name) if instance && instance.user_name != instance_info.name
    instance ||= User.create!(team: client.owner, user_id: slack_id, user_name: instance_info.name)
    instance
  end

  def to_s
    "user_id=#{user_id}, user_name=#{user_name}"
  end

  def connect!(code)
    response = Strava::Api::V3::Auth.retrieve_access(ENV['STRAVA_CLIENT_ID'], ENV['STRAVA_CLIENT_SECRET'], code)
    if response.success?
      create_athlete(athlete_id: response['athlete']['id'])
      update_attributes!(token_type: response['token_type'], access_token: response['access_token'])
      Api::Middleware.logger.info "Connected team=#{team_id}, user=#{user_name}, user_id=#{id}, athlete_id=#{athlete.athlete_id}"
      activity = sync_strava_activities.first
      channels = brag_activity!(activity) if activity
      if activity && channels && channels.any?
        dm!(text: "Your Strava account has been successfully connected. I've posted \"#{activity.name}\" to #{channels.and}.")
      else
        dm!(text: 'Your Strava account has been successfully connected.')
      end
    else
      raise "Strava returned #{response.code}: #{response.body}"
    end
  end

  def dm!(message)
    client = Slack::Web::Client.new(token: team.token)
    im = client.im_open(user: user_id)
    client.chat_postMessage(message.merge(channel: im['channel']['id'], as_user: true))
  end

  def brag!
    activity = new_strava_activities.last
    return unless activity
    brag_activity!(activity)
  end

  def brag_activity!(activity)
    return if activity.bragged_at
    Api::Middleware.logger.info "Bragging about #{self}, #{activity}"
    channels = team.brag!(activity.to_slack)
    activity.update_attributes!(bragged_at: Time.now.utc)
    update_attributes!(activities_at: activity.start_date) unless activities_at && activities_at > activity.start_date
    channels
  end

  def sync_strava_activities(options = {})
    raise 'Missing access_token' unless access_token
    client = Strava::Api::V3::Client.new(access_token: access_token)
    page = 1
    page_size = 10
    result = []
    loop do
      activities = client.list_athlete_activities(options.merge(page: page, per_page: page_size))
      result.concat(activities.map { |activity| Activity.create_from_strava!(self, activity) })
      break if activities.size < page_size
      page += 1
    end
    result
  end

  def new_strava_activities
    sync_strava_activities(after: activities_at || created_at)
  end
end
