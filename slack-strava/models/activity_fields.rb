class ActivityFields
  include Ruby::Enum

  define :DEFAULT, 'Default'
  define :ALL, 'All'
  define :NONE, 'None'
  define :TYPE, 'Type'
  define :DISTANCE, 'Distance'
  define :TIME, 'Time'
  define :MOVING_TIME, 'Moving Time'
  define :ELAPSED_TIME, 'Elapsed Time'
  define :PACE, 'Pace'
  define :SPEED, 'Speed'
  define :ELEVATION, 'Elevation'
  define :MAX_SPEED, 'Max Speed'
  define :HEART_RATE, 'Heart Rate'
  define :MAX_HEART_RATE, 'Max Heart Rate'
  define :PR_COUNT, 'PR Count'
  define :CALORIES, 'Calories'
  define :WEATHER, 'Weather'

  DEFAULT_VALUES = ['Type', 'Distance', 'Time', 'Moving Time', 'Elapsed Time', 'Pace', 'Speed', 'Elevation', 'Weather'].freeze

  def self.parse_s(values)
    return unless values

    errors = []
    fields = []
    values.scan(/[\w\s']+/).map do |v|
      v = v.strip
      title = v.titleize
      if value?(title)
        fields << title
      else
        errors << v
      end
    end

    fields.uniq!
    errors.uniq!

    if errors.any?
      raise SlackStrava::Error, "Invalid field#{errors.count == 1 ? '' : 's'}: #{errors.and}, possible values are #{ActivityFields.values.and}."
    end

    if fields.count > 1
      if fields.include?('None')
        raise SlackStrava::Error, 'None cannot be used with other fields.'
      elsif fields.include?('Default')
        raise SlackStrava::Error, 'Default cannot be used with other fields.'
      elsif fields.include?('All')
        raise SlackStrava::Error, 'All cannot be used with other fields.'
      end
    end

    fields
  end
end
