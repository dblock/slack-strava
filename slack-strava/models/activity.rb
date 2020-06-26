class Activity
  include Mongoid::Document
  include Mongoid::Timestamps
  include ActivityMethods

  field :strava_id, type: String
  field :name, type: String
  field :distance, type: Float
  field :description, type: String
  field :moving_time, type: Float
  field :elapsed_time, type: Float
  field :average_speed, type: Float
  field :max_speed, type: Float
  field :average_heartrate, type: Float
  field :max_heartrate, type: Float
  field :pr_count, type: Integer
  field :calories, type: Float
  field :bragged_at, type: DateTime
  field :total_elevation_gain, type: Float
  field :private, type: Boolean
  field :visibility, type: String
  field :type, type: String

  index(strava_id: 1)
  index(team_id: 1, bragged_at: 1)
  index(distance: 1, moving_time: 1, elapsed_time: 1, total_elevation_gain: 1)

  embeds_many :channel_messages, inverse_of: nil
  index('channel_messages.channel' => 1)

  scope :unbragged, -> { where(bragged_at: nil) }
  scope :bragged, -> { where(:bragged_at.ne => nil) }

  belongs_to :team, inverse_of: :activities
  index(team_id: 1)
  validates_presence_of :team_id

  before_update :reset_bragged_at

  def hidden?
    false
  end

  def to_s
    "name=#{name}, distance=#{distance_s}, moving time=#{moving_time_in_hours_s}, pace=#{pace_s}, speed=#{speed_s}"
  end

  def strava_url
    "https://www.strava.com/activities/#{strava_id}"
  end

  def to_slack
    {
      attachments: [
        to_slack_attachment
      ]
    }
  end

  def self.attrs_from_strava(response)
    {
      strava_id: response.id,
      name: response.name,
      distance: response.distance,
      moving_time: response.moving_time,
      elapsed_time: response.elapsed_time,
      average_speed: response.average_speed,
      max_speed: response.max_speed,
      average_heartrate: response.average_heartrate,
      max_heartrate: response.max_heartrate,
      pr_count: response.pr_count,
      type: response.type,
      total_elevation_gain: response.total_elevation_gain,
      private: response.private,
      visibility: response.visibility,
      description: response.description
    }
  end

  alias eql? ==

  def ==(other)
    other.is_a?(Activity) &&
      distance == other.distance &&
      moving_time == other.moving_time &&
      elapsed_time == other.elapsed_time &&
      total_elevation_gain == other.total_elevation_gain
  end

  # Have we recently bragged an identically looking user activity?
  def bragged_in?(channel_id, dt = 48.hours)
    Activity.where(
      team_id: team.id,
      distance: distance,
      moving_time: moving_time,
      elapsed_time: elapsed_time,
      total_elevation_gain: total_elevation_gain,
      :bragged_at.gt => Time.now.utc.to_i - dt.to_i,
      "channel_messages.channel": channel_id
    ).exists?
  end

  # Have we recently skipped bragging of an identically looking private or followers only activity?
  def privately_bragged?(dt = 48.hours)
    Activity.where(
      team_id: team.id,
      distance: distance,
      moving_time: moving_time,
      elapsed_time: elapsed_time,
      total_elevation_gain: total_elevation_gain,
      :bragged_at.gt => Time.now.utc.to_i - dt.to_i
    ).any? do |activity|
      activity.private? || activity.visibility == 'only_me' || activity.visibility == 'followers_only'
    end
  end

  def reset_bragged_at(dt = 48.hours)
    return unless bragged_at
    return unless private_changed? || visibility_changed?
    return if channel_messages.any?
    return if bragged_at < Time.now.utc - dt

    self.bragged_at = nil
  end
end
