class Activity
  include Mongoid::Document
  include Mongoid::Timestamps

  field :strava_id, type: String
  field :name, type: String
  field :distance, type: Float
  field :moving_time, type: Float
  field :elapsed_time, type: Float
  field :average_speed, type: Float
  field :bragged_at, type: DateTime
  field :total_elevation_gain, type: Float
  field :private, type: Boolean
  field :type, type: String

  index(strava_id: 1)

  scope :unbragged, -> { where(bragged_at: nil) }
  scope :bragged, -> { where(:bragged_at.ne => nil) }

  def distance_in_miles
    distance * 0.00062137
  end

  def distance_in_miles_s
    return unless distance && distance.positive?
    format('%gmi', format('%.2f', distance_in_miles))
  end

  def distance_in_yards
    distance * 1.09361
  end

  def distance_in_yards_s
    return unless distance && distance.positive?
    format('%gyd', format('%.1f', distance_in_yards))
  end

  def distance_in_meters_s
    return unless distance && distance.positive?
    format('%gm', format('%d', distance))
  end

  def distance_in_kilometers
    distance / 1000
  end

  def distance_in_kilometers_s
    return unless distance && distance.positive?
    format('%gkm', format('%.2f', distance_in_kilometers))
  end

  def distance_s
    if type == 'Swim'
      case team.units
      when 'km' then distance_in_meters_s
      when 'mi' then distance_in_yards_s
      end
    else
      case team.units
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

  def pace_per_100_meters_s
    convert_meters_per_second_to_pace average_speed, :"100m"
  end

  def pace_per_kilometer_s
    convert_meters_per_second_to_pace average_speed, :km
  end

  def kilometer_per_hour_s
    return unless average_speed && average_speed.positive?
    format('%.1fkm/h', average_speed * 3.6)
  end

  def miles_per_hour_s
    return unless average_speed && average_speed.positive?
    format('%.1fmph', average_speed * 2.23694)
  end

  def total_elevation_gain_in_feet
    total_elevation_gain_in_meters * 3.28084
  end

  def total_elevation_gain_in_meters
    total_elevation_gain
  end

  def total_elevation_gain_in_meters_s
    return unless total_elevation_gain && total_elevation_gain.positive?
    format('%gm', format('%.1f', total_elevation_gain_in_meters))
  end

  def total_elevation_gain_in_feet_s
    return unless total_elevation_gain && total_elevation_gain.positive?
    format('%gft', format('%.1f', total_elevation_gain_in_feet))
  end

  def total_elevation_gain_s
    case team.units
    when 'km' then total_elevation_gain_in_meters_s
    when 'mi' then total_elevation_gain_in_feet_s
    end
  end

  def pace_s
    case type
    when 'Swim'
      case team.units
      when 'km' then pace_per_100_meters_s
      when 'mi' then pace_per_100_yards_s
      end
    else
      case team.units
      when 'km' then pace_per_kilometer_s
      when 'mi' then pace_per_mile_s
      end
    end
  end

  def speed_s
    case team.units
    when 'km' then kilometer_per_hour_s
    when 'mi' then miles_per_hour_s
    end
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
      strava_id: response['id'],
      name: response['name'],
      distance: response['distance'],
      moving_time: response['moving_time'],
      elapsed_time: response['elapsed_time'],
      average_speed: response['average_speed'],
      type: response['type'],
      total_elevation_gain: response['total_elevation_gain'],
      private: response['private']
    }
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
    when 'AlpineSki' then '⛷️'
    when 'BackcountrySki' then '🎿️'
    # when 'Canoeing' then ''
    # when 'Crossfit' then ''
    when 'EBikeRide' then '🚴'
    # when 'Elliptical' then ''
    # when 'Hike' then ''
    when 'IceSkate' then '⛸️'
    # when 'InlineSkate' then ''
    # when 'Kayaking' then ''
    # when 'Kitesurf' then ''
    # when 'NordicSki' then ''
    when 'RockClimbing' then '🧗'
    when 'RollerSki' then ''
    when 'Rowing' then '🚣'
    when 'Snowboard' then '🏂'
    # when 'Snowshoe' then ''
    # when 'StairStepper' then ''
    # when 'StandUpPaddling' then ''
    when 'Surfing' then '🏄'
    when 'VirtualRide' then '🚴'
    when 'VirtualRun' then '🏃'
    when 'WeightTraining' then '🏋️'
    # when 'Windsurf' then ''
    when 'Wheelchair' then '♿'
      # when 'Workout' then ''
      # when 'Yoga'' then ''
    end
  end

  def type_with_emoji
    [type, emoji].compact.join(' ')
  end

  def slack_fields
    activity_fields = team.activity_fields
    return if activity_fields == ['None']
    activity_fields = ActivityFields.values if activity_fields == ['All']

    fields = []
    activity_fields.each do |activity_field|
      case activity_field
      when 'Type' then
        fields << { title: 'Type', value: type_with_emoji, short: true }
      when 'Distance' then
        fields << { title: 'Distance', value: distance_s, short: true } if distance && distance.positive?
      when 'Time' then
        if elapsed_time && moving_time
          if elapsed_time == moving_time
            fields << { title: 'Time', value: moving_time_in_hours_s, short: true }
          end
        elsif moving_time
          fields << { title: 'Time', value: moving_time_in_hours_s, short: true }
        elsif elapsed_time
          fields << { title: 'Time', value: elapsed_time_in_hours_s, short: true }
        end
      when 'Moving Time' then
        if elapsed_time && moving_time && elapsed_time != moving_time
          fields << { title: 'Moving Time', value: moving_time_in_hours_s, short: true }
        end
      when 'Elapsed Time' then
        if elapsed_time && moving_time && elapsed_time != moving_time
          fields << { title: 'Elapsed Time', value: elapsed_time_in_hours_s, short: true }
        end
      when 'Pace' then
        fields << { title: 'Pace', value: pace_s, short: true } if average_speed
      when 'Speed' then
        fields << { title: 'Speed', value: speed_s, short: true } if average_speed
      when 'Elevation' then
        fields << { title: 'Elevation', value: total_elevation_gain_s, short: true } if total_elevation_gain && total_elevation_gain.positive?
      end
    end
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
                    when :"100m" then 100 / speed
                    end
    minutes, seconds = total_seconds.divmod(60)
    seconds = seconds.round < 10 ? "0#{seconds.round}" : seconds.round.to_s
    "#{minutes}m#{seconds}s/#{unit}"
  end
end
