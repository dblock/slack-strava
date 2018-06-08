class MapTypes
  include Ruby::Enum

  define :FULL, 'full'
  define :OFF, 'off'
  define :THUMB, 'thumb'

  def self.parse_s(s)
    return unless s
    value = parse(s)
    raise SlackStrava::Error, "Invalid value: #{s}, possible values are #{MapTypes.values.and}." unless value
    value
  end
end
