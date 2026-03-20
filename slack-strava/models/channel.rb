class Channel
  include Mongoid::Document
  include Mongoid::Timestamps

  field :channel_id, type: String
  field :channel_name, type: String
  field :activity_types, type: Array, default: []

  belongs_to :team

  index({ team_id: 1, channel_id: 1 }, unique: true)

  validates_presence_of :team_id, :channel_id

  def activity_types_s
    activity_types.blank? ? 'all' : activity_types.join(', ')
  end
end
