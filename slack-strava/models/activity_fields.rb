class ActivityFields
  include Ruby::Enum

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
    raise SlackStrava::Error, "Invalid field#{errors.count == 1 ? '' : 's'}: #{errors.and}, possible values are #{ActivityFields.values.and}." if errors.any?
    raise SlackStrava::Error, 'None cannot be used with other fields.' if fields.include?('None') && fields.count != 1
    raise SlackStrava::Error, 'All cannot be used with other fields.' if fields.include?('All') && fields.count != 1
    fields
  end
end
