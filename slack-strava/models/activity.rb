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
  field :type, type: String

  index(strava_id: 1)
  index(user_id: 1)

  embeds_one :map

  scope :unbragged, -> { where(bragged_at: nil) }
  scope :bragged, -> { where(:bragged_at.ne => nil) }

  def start_date_local_s
    start_date_local.strftime('%F %T')
  end

  def distance_in_miles
    distance * 0.00062137
  end

  def distance_in_miles_s
    format '%.2fmi', distance_in_miles
  end

  def distance_in_kilometers
    distance / 1000
  end

  def distance_in_kilometers_s
    format '%.2fkm', distance_in_kilometers
  end

  def distance_s
    case user.team.units
    when 'km' then distance_in_kilometers_s
    when 'mi' then distance_in_miles_s
    end
  end

  def time_in_hours_s
    hours = moving_time / 3600 % 24
    minutes = moving_time / 60 % 60
    seconds = moving_time % 60
    [
      hours.to_i > 0 ? format('%dh', hours) : nil,
      minutes.to_i > 0 ? format('%dm', minutes) : nil,
      seconds.to_i > 0 ? format('%ds', seconds) : nil
    ].compact.join
  end

  def pace_per_mile_s
    convert_meters_per_second_to_pace average_speed, :mi
  end

  def pace_per_kilometer_s
    convert_meters_per_second_to_pace average_speed, :km
  end

  def pace_s
    case user.team.units
    when 'km' then pace_per_kilometer_s
    when 'mi' then pace_per_mile_s
    end
  end

  def to_s
    "name=#{name}, start_date=#{start_date_local_s}, distance=#{distance_s}, time=#{time_in_hours_s}, pace=#{pace_s}, #{map}"
  end

  def strava_url
    "https://www.strava.com/activities/#{strava_id}"
  end

  def to_slack
    {
      attachments: [
        fallback: "#{name} via #{user.slack_mention}, #{distance_s} #{time_in_hours_s} #{pace_s}",
        title: "#{name} via <@#{user.user_name}>",
        title_link: strava_url,
        image_url: map.proxy_image_url,
        fields: [
          { title: 'Type', value: type, short: true },
          { title: 'Distance', value: distance_s, short: true },
          { title: 'Time', value: time_in_hours_s, short: true },
          { title: 'Pace', value: pace_s, short: true }
        ]
      ]
    }
  end

  def brag!
    return if bragged_at
    Api::Middleware.logger.info "Bragging about #{user}, #{self}"
    channels = user.team.brag!(to_slack)
    update_attributes!(bragged_at: Time.now.utc)
    channels
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
    activity.type = h['type']
    activity.map = Map.new(
      strava_id: h['map']['id'],
      summary_polyline: h['map']['summary_polyline']
    )
    activity.save!
    activity.map.save!
    activity
  end

  private

  # Convert speed (m/s) to pace (min/mile or min/km) in the format of 'x:xx'
  # http://yizeng.me/2017/02/25/convert-speed-to-pace-programmatically-using-ruby
  def convert_meters_per_second_to_pace(speed, unit = :mi)
    return if speed == 0
    total_seconds = unit == :mi ? (1609.344 / speed) : (1000 / speed)
    minutes, seconds = total_seconds.divmod(60)
    seconds = seconds.round < 10 ? "0#{seconds.round}" : seconds.round.to_s
    "#{minutes}m#{seconds}s/#{unit}"
  end
end
