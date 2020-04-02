class ActivitySummary
  include ActivityMethods
  extend Forwardable

  FIELDS = %i[
    distance
    moving_time
    elapsed_time
    pr_count
    calories
    total_elevation_gain
  ].freeze

  attr_reader(*FIELDS)
  attr_accessor :type, :team, :count, :athlete_count

  attr_reader :stats
  def_delegators :@stats, *FIELDS

  attr_reader :average_heartrate, :average_speed, :max_speed, :max_heartrate

  def initialize(options = {})
    @team = options[:team]
    @count = options[:count]
    @type = options[:type]
    @athlete_count = options[:athlete_count]
    @stats = Hashie::Mash.new(options[:stats])
  end

  def stats=(values)
    @stats = Hashie::Mash.new(values)
  end

  def type_with_emoji
    [type.pluralize, emoji].compact.join(' ')
  end

  def slack_fields
    [
      { short: true, title: type_with_emoji, value: count.to_s },
      { short: true, title: 'Athletes', value: athlete_count.to_s }
    ].concat(super.reject { |row| row[:title] == 'Type' })
  end

  def to_h
    stats.to_hash.symbolize_keys
  end

  def to_slack_attachment
    result = {}
    result[:fallback] = "#{distance_s} in #{moving_time_in_hours_s}"
    result[:fields] = slack_fields
    result
  end
end
