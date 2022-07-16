module ActivityMethods
  include ActiveSupport::Concern

  UNIT_SEPARATOR = ' '.freeze

  #   field :name, type: String
  #   field :distance, type: Float
  #   field :moving_time, type: Float
  #   field :elapsed_time, type: Float
  #   field :average_speed, type: Float
  #   field :max_speed, type: Float
  #   field :average_heartrate, type: Float
  #   field :max_heartrate, type: Float
  #   field :pr_count, type: Integer
  #   field :calories, type: Float
  #   field :total_elevation_gain, type: Float
  #   field :type, type: String

  def distance_in_miles
    distance * 0.00062137
  end

  def distance_in_miles_s
    return unless distance&.positive?

    format('%gmi', format('%.2f', distance_in_miles))
  end

  def distance_in_yards
    distance * 1.09361
  end

  def distance_in_yards_s
    return unless distance&.positive?

    format('%gyd', format('%.1f', distance_in_yards))
  end

  def distance_in_meters_s
    return unless distance&.positive?

    format('%gm', format('%d', distance))
  end

  def distance_in_kilometers
    distance / 1000
  end

  def distance_in_kilometers_s
    return unless distance&.positive?

    format('%gkm', format('%.2f', distance_in_kilometers))
  end

  def distance_s
    if type == 'Swim'
      case team.units
      when 'km' then distance_in_meters_s
      when 'mi' then distance_in_yards_s
      when 'both' then [distance_in_yards_s, distance_in_meters_s].join(UNIT_SEPARATOR)
      end
    else
      case team.units
      when 'km' then distance_in_kilometers_s
      when 'mi' then distance_in_miles_s
      when 'both' then [distance_in_miles_s, distance_in_kilometers_s].join(UNIT_SEPARATOR)
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
    convert_meters_per_second_to_pace average_speed, :'100yd'
  end

  def pace_per_100_meters_s
    convert_meters_per_second_to_pace average_speed, :'100m'
  end

  def pace_per_kilometer_s
    convert_meters_per_second_to_pace average_speed, :km
  end

  def kilometer_per_hour_s
    return unless average_speed&.positive?

    format('%.1fkm/h', average_speed * 3.6)
  end

  def max_kilometer_per_hour_s
    return unless max_speed&.positive?

    format('%.1fkm/h', max_speed * 3.6)
  end

  def miles_per_hour_s
    return unless average_speed&.positive?

    format('%.1fmph', average_speed * 2.23694)
  end

  def max_miles_per_hour_s
    return unless max_speed&.positive?

    format('%.1fmph', max_speed * 2.23694)
  end

  def total_elevation_gain_in_feet
    total_elevation_gain_in_meters * 3.28084
  end

  def total_elevation_gain_in_meters
    total_elevation_gain
  end

  def total_elevation_gain_in_meters_s
    return unless total_elevation_gain&.positive?

    format('%gm', format('%.1f', total_elevation_gain_in_meters))
  end

  def total_elevation_gain_in_feet_s
    return unless total_elevation_gain&.positive?

    format('%gft', format('%.1f', total_elevation_gain_in_feet))
  end

  def total_elevation_gain_s
    case team.units
    when 'km' then total_elevation_gain_in_meters_s
    when 'mi' then total_elevation_gain_in_feet_s
    when 'both' then [total_elevation_gain_in_feet_s, total_elevation_gain_in_meters_s].join(UNIT_SEPARATOR)
    end
  end

  def pace_s
    case type
    when 'Swim'
      case team.units
      when 'km' then pace_per_100_meters_s
      when 'mi' then pace_per_100_yards_s
      when 'both' then [pace_per_100_yards_s, pace_per_100_meters_s].join(UNIT_SEPARATOR)
      end
    else
      case team.units
      when 'km' then pace_per_kilometer_s
      when 'mi' then pace_per_mile_s
      when 'both' then [pace_per_mile_s, pace_per_kilometer_s].join(UNIT_SEPARATOR)
      end
    end
  end

  def speed_s
    case team.units
    when 'km' then kilometer_per_hour_s
    when 'mi' then miles_per_hour_s
    when 'both' then [miles_per_hour_s, kilometer_per_hour_s].join(UNIT_SEPARATOR)
    end
  end

  def max_speed_s
    case team.units
    when 'km' then max_kilometer_per_hour_s
    when 'mi' then max_miles_per_hour_s
    when 'both' then [max_miles_per_hour_s, max_kilometer_per_hour_s].join(UNIT_SEPARATOR)
    end
  end

  def max_heartrate_s
    return unless max_heartrate&.positive?

    format('%.1fbpm', max_heartrate)
  end

  def average_heartrate_s
    return unless average_heartrate&.positive?

    format('%.1fbpm', average_heartrate)
  end

  def pr_count_s
    return unless pr_count&.positive?

    format('%d', pr_count)
  end

  def calories_s
    return unless calories&.positive?

    format('%.1f', calories)
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

  def slack_fields
    activity_fields = team.activity_fields

    case activity_fields
    when ['All']
      activity_fields = ActivityFields.values
    when ['Default']
      activity_fields = ActivityFields::DEFAULT_VALUES
    when ['None']
      return
    end

    fields = []
    activity_fields.each do |activity_field|
      case activity_field
      when 'Type'
        fields << { title: 'Type', value: type_with_emoji, short: true }
      when 'Distance'
        fields << { title: 'Distance', value: distance_s, short: true } if distance&.positive?
      when 'Time'
        if elapsed_time && moving_time
          fields << { title: 'Time', value: moving_time_in_hours_s, short: true } if elapsed_time == moving_time
        elsif moving_time
          fields << { title: 'Time', value: moving_time_in_hours_s, short: true }
        elsif elapsed_time
          fields << { title: 'Time', value: elapsed_time_in_hours_s, short: true }
        end
      when 'Moving Time'
        fields << { title: 'Moving Time', value: moving_time_in_hours_s, short: true } if elapsed_time && moving_time && elapsed_time != moving_time
      when 'Elapsed Time'
        fields << { title: 'Elapsed Time', value: elapsed_time_in_hours_s, short: true } if elapsed_time && moving_time && elapsed_time != moving_time
      when 'Pace'
        fields << { title: 'Pace', value: pace_s, short: true } if average_speed
      when 'Speed'
        fields << { title: 'Speed', value: speed_s, short: true } if average_speed
      when 'Max Speed'
        fields << { title: 'Max Speed', value: max_speed_s, short: true } if max_speed
      when 'Elevation'
        fields << { title: 'Elevation', value: total_elevation_gain_s, short: true } if total_elevation_gain&.positive?
      when 'Heart Rate'
        fields << { title: 'Heart Rate', value: average_heartrate_s, short: true } if average_heartrate&.positive?
      when 'Max Heart Rate'
        fields << { title: 'Max Heart Rate', value: max_heartrate_s, short: true } if max_heartrate&.positive?
      when 'PR Count'
        fields << { title: 'PR Count', value: pr_count_s, short: true } if pr_count&.positive?
      when 'Calories'
        fields << { title: 'Calories', value: calories_s, short: true } if calories&.positive?
      when 'Weather'
        fields << { title: 'Weather', value: weather_s, short: true } if respond_to?(:weather) && weather.present?
      end
    end
    fields.any? ? fields : nil
  end

  # Convert speed (m/s) to pace (min/mile or min/km) in the format of 'x:xx'
  # http://yizeng.me/2017/02/25/convert-speed-to-pace-programmatically-using-ruby
  def convert_meters_per_second_to_pace(speed, unit = :mi)
    return unless speed&.positive?

    total_seconds = case unit
                    when :mi then 1609.344 / speed
                    when :km then 1000 / speed
                    when :'100yd' then 91.44 / speed
                    when :'100m' then 100 / speed
                    end
    minutes, seconds = total_seconds.divmod(60)
    seconds = seconds.round
    if seconds == 60
      minutes += 1
      seconds = 0
    end
    seconds = seconds < 10 ? "0#{seconds}" : seconds.to_s
    "#{minutes}m#{seconds}s/#{unit}"
  end
end
