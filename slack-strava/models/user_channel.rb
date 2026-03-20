class UserChannel
  include Mongoid::Document
  include Mongoid::Timestamps

  field :channel_id, type: String
  field :channel_name, type: String
  field :sync_activities, type: Boolean

  belongs_to :user
  belongs_to :team

  index({ user_id: 1, channel_id: 1 }, unique: true)
  index(team_id: 1, channel_id: 1)

  validates_presence_of :user_id, :team_id, :channel_id
end
