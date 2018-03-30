class Activity
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :user

  field :strava_id, type: String
  field :name, type: String
  field :start_date, type: DateTime
  field :start_date_local, type: DateTime
  field :distance, type: Float
  field :moving_time, type: Float
  field :average_speed, type: Float
  field :bragged_at, type: DateTime

  index(strava_id: 1)
  index(user_id: 1)

  embeds_one :map

  def start_date_local_s
    start_date_local.strftime('%F %T')
  end

  def distance_in_miles
    distance * 0.00062137
  end

  def distance_in_miles_s
    format '%.2fmi', distance_in_miles
  end

  def time_in_hours_s
    format '%dh%02dm%02ds', moving_time / 3600 % 24, moving_time / 60 % 60, moving_time % 60
  end

  def average_speed_mph_s
    format '%.2fmph', average_speed * 2.23694
  end

  def pace_per_mile_s
    Time.at((60 * 60) / (average_speed * 2.23694)).utc.strftime('%M:%S min/mi')
  end

  def to_s
    "name=#{name}, start_date=#{start_date_local_s}, distance=#{distance_in_miles_s}, time=#{time_in_hours_s}, pace=#{pace_per_mile_s}"
  end

  def self.create_from_strava!(user, h)
    activity = Activity.where(strava_id: h['id'], user_id: user.id).first
    activity ||= Activity.new(strava_id: h['id'], user_id: user.id)
    activity.name = h['name']
    activity.start_date = DateTime.parse(h['start_date'])
    activity.start_date_local = DateTime.parse(h['start_date_local'])
    activity.distance = h['distance']
    activity.moving_time = h['moving_time']
    activity.average_speed = h['average_speed']
    activity.map = Map.new(
      strava_id: h['map']['id'],
      summary_polyline: h['map']['summary_polyline']
    )
    activity.save!
    activity
  end
end
