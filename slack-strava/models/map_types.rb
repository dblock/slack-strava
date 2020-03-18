class MapTypes
  include Ruby::Enum

  define :FULL, 'full'
  define :OFF, 'off'
  define :THUMB, 'thumb'

  def self.parse_s(s)
    return unless s

    value = parse(s)
    unless value
      raise SlackStrava::Error, "Invalid value: #{s}, possible values are #{MapTypes.values.and}."
    end

    value
  end
end
