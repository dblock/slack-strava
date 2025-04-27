class ThreadTypes
  include Ruby::Enum

  define :NONE, 'none'
  define :DAILY, 'daily'
  define :WEEKLY, 'weekly'
  define :MONTHLY, 'monthly'

  def self.parse_s(s)
    return unless s

    value = parse(s)
    raise SlackStrava::Error, "Invalid value: #{s}, possible values are #{ThreadTypes.values.and}." unless value

    value
  end
end
