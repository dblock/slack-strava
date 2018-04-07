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
  field :elapsed_time, type: Float
  field :average_speed, type: Float
  field :bragged_at, type: DateTime
  field :total_elevation_gain, type: Float
  field :type, type: String

  index(strava_id: 1)
  index(user_id: 1)

  embeds_one :map

  scope :unbragged, -> { where(bragged_at: nil) }
  scope :bragged, -> { where(:bragged_at.ne => nil) }

  def start_date_local_s
    return unless start_date_local
    start_date_local.strftime('%A, %B %d, %Y at %I:%M %p')
  end

  def distance_in_miles
    distance * 0.00062137
  end

  def distance_in_miles_s
    return unless distance
    format '%.2fmi', distance_in_miles
  end

  def distance_in_yards
    distance * 1.09361
  end

  def distance_in_yards_s
    return unless distance
    format '%.1fyd', distance_in_yards
  end

  def distance_in_kilometers
    distance / 1000
  end

  def distance_in_kilometers_s
    return unless distance
    format '%.2fkm', distance_in_kilometers
  end

  def distance_s
    if type == 'Swim'
      distance_in_yards_s
    else
      case user.team.units
      when 'km' then distance_in_kilometers_s
      when 'mi' then distance_in_miles_s
      end
    end
  end

  def moving_time_in_hours_s
    time_in_hours_s moving_time
  end

  def elapsed_time_in_hours_s
    time_in_hours_s elapsed_time
  end

  def pace_per_mile_s
    convert_meters_per_second_to_pace average_speed, :mi
  end

  def pace_per_100_yards_s
    convert_meters_per_second_to_pace average_speed, :"100yd"
  end

  def pace_per_kilometer_s
    convert_meters_per_second_to_pace average_speed, :km
  end

  def total_elevation_gain_in_feet
    total_elevation_gain_in_meters * 3.28084
  end

  def total_elevation_gain_in_meters
    total_elevation_gain
  end

  def total_elevation_gain_in_meters_s
    return unless total_elevation_gain
    format '%.1fm', total_elevation_gain_in_meters
  end

  def total_elevation_gain_in_feet_s
    return unless total_elevation_gain
    format '%.1fft', total_elevation_gain_in_feet
  end

  def total_elevation_gain_s
    case user.team.units
    when 'km' then total_elevation_gain_in_meters_s
    when 'mi' then total_elevation_gain_in_feet_s
    end
  end

  def pace_s
    if type == 'Swim'
      pace_per_100_yards_s
    else
      case user.team.units
      when 'km' then pace_per_kilometer_s
      when 'mi' then pace_per_mile_s
      end
    end
  end

  def to_s
    "name=#{name}, start_date=#{start_date}, distance=#{distance_s}, moving time=#{moving_time_in_hours_s}, pace=#{pace_s}, #{map}"
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

  def brag!
    return if bragged_at
    Api::Middleware.logger.info "Bragging about #{user}, #{self}"
    channels = user.team.brag!(to_slack)
    update_attributes!(bragged_at: Time.now.utc)
    channels
  end

  def self.attrs_from_strava(response)
    {
      name: response['name'],
      start_date: DateTime.parse(response['start_date']),
      start_date_local: DateTime.parse(response['start_date_local']),
      distance: response['distance'],
      moving_time: response['moving_time'],
      elapsed_time: response['elapsed_time'],
      average_speed: response['average_speed'],
      type: response['type'],
      total_elevation_gain: response['total_elevation_gain']
    }
  end

  def self.create_from_strava!(user, response)
    activity = Activity.where(strava_id: response['id'], user_id: user.id).first
    activity ||= Activity.new(strava_id: response['id'], user_id: user.id)
    activity.assign_attributes(attrs_from_strava(response))
    activity.build_map(Map.attrs_from_strava(response['map']))
    activity.map.update!
    activity.save!
    activity
  end

  private

  def time_in_hours_s(time)
    return unless time
    hours = time / 3600 % 24
    minutes = time / 60 % 60
    seconds = time % 60
    [
      hours.to_i.positive? ? format('%dh', hours) : nil,
      minutes.to_i.positive? ? format('%dm', minutes) : nil,
      seconds.to_i.positive? ? format('%ds', seconds) : nil
    ].compact.join
  end

  def emoji
    case type
    when 'Run' then '🏃'
    when 'Ride' then '🚴'
    when 'Swim' then '🏊'
    when 'Walk' then '🚶'
    # when 'Hike' then ''
    when 'Alpine Ski' then '⛷️'
    when 'Backcountry Ski' then '🎿️'
    # when 'Canoe' then ''
    # when 'Crossfit' then ''
    when 'E-Bike Ride' then '🚴'
    # when 'Elliptical' then ''
    # when 'Handcycle' then ''
    when 'Ice Skate' then '⛸️'
    # when 'Inline Skate' then ''
    # when 'Kayak' then ''
    # when 'Kitesurf Session' then ''
    # when 'Nordic Ski' then ''
    when 'Rock Climb' then '🧗'
    when 'Roller Ski' then ''
    when 'Row' then '🚣'
    when 'Snowboard' then '🏂'
    # when 'Snowshoe' then ''
    # when 'Stair Stepper' then ''
    # when 'Stand Up Paddle' then ''
    when 'Surf' then '🏄'
    when 'Virtual Ride' then '🚴'
    when 'Virtual Run' then '🏃'
    when 'Weight Training' then '🏋️'
    # when 'Windsurf Session' then ''
    when 'Wheelchair' then '♿'
      # when 'Workout' then ''
      # when 'Yoga'' then ''
    end
  end

  def type_with_emoji
    [type, emoji].compact.join(' ')
  end

  def to_slack_attachment
    result = {}
    result[:fallback] = "#{name} via #{user.slack_mention}, #{distance_s} #{moving_time_in_hours_s} #{pace_s}"
    result[:title] = name
    result[:title_link] = strava_url
    result[:text] = "<@#{user.user_name}> on #{start_date_local_s}"
    result[:image_url] = map.proxy_image_url if map
    result[:fields] = slack_fields
    result.merge!(user.athlete.to_slack) if user.athlete
    result
  end

  def slack_fields
    fields = [
      { title: 'Type', value: type_with_emoji, short: true }
    ]

    fields << { title: 'Distance', value: distance_s, short: true } if distance

    if elapsed_time && moving_time
      if elapsed_time == moving_time
        fields << { title: 'Time', value: moving_time_in_hours_s, short: true }
      else
        fields << { title: 'Moving Time', value: moving_time_in_hours_s, short: true }
        fields << { title: 'Elapsed Time', value: elapsed_time_in_hours_s, short: true }
      end
    elsif moving_time
      fields << { title: 'Time', value: moving_time_in_hours_s, short: true }
    elsif elapsed_time
      fields << { title: 'Time', value: elapsed_time_in_hours_s, short: true }
    end

    fields << { title: 'Pace', value: pace_s, short: true } if average_speed
    fields << { title: 'Elevation', value: total_elevation_gain_s, short: true } if total_elevation_gain

    fields
  end

  # Convert speed (m/s) to pace (min/mile or min/km) in the format of 'x:xx'
  # http://yizeng.me/2017/02/25/convert-speed-to-pace-programmatically-using-ruby
  def convert_meters_per_second_to_pace(speed, unit = :mi)
    return unless speed && speed.positive?
    total_seconds = case unit
                    when :mi then 1609.344 / speed
                    when :km then 1000 / speed
                    when :"100yd" then 91.44 / speed
                    end
    minutes, seconds = total_seconds.divmod(60)
    seconds = seconds.round < 10 ? "0#{seconds.round}" : seconds.round.to_s
    "#{minutes}m#{seconds}s/#{unit}"
  end
end
