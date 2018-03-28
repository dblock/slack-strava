class User
  include Mongoid::Document
  include Mongoid::Timestamps

  field :user_id, type: String
  field :user_name, type: String

  belongs_to :team, index: true
  validates_presence_of :team

  index({ user_id: 1, team_id: 1 }, unique: true)
  index(user_name: 1, team_id: 1)

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
    user_name
  end
end
