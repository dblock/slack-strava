class TeamLeaderboard
  include ActiveModel::Model

  class Row
    include ActivityMethods
    extend Forwardable

    attr_accessor :type, :team, :field, :value, :user, :rank

    def initialize(options = {})
      @team = options[:team]
      @type = options[:type]
      @field = options[:field]
      @value = options[:value]
      @user = options[:user]
      @rank = options[:rank]
    end

    def to_s
      ["#{rank}:", user.user_name, emoji, send("#{field.gsub(' ', '_')}_s")].join(' ').to_s
    end

    alias count_s value
    alias pr_count_s value
    alias total_elevation_gain value
    alias moving_time value
    alias elapsed_time value

    alias elevation_s total_elevation_gain_s
    alias time_s moving_time_in_hours_s
    alias moving_time_s moving_time_in_hours_s
    alias elapsed_time_s elapsed_time_in_hours_s

    def method_missing(method, *args)
      if method.to_s == field
        value
      else
        super
      end
    end
  end

  MEASURABLE_VALUES = [
    'Count', 'Distance', 'Moving Time', 'Elapsed Time', 'Elevation', 'PR Count', 'Calories'
  ].freeze

  # MIN_MAX_VALUES = [
  #   'Pace', 'Speed', 'Max Speed', 'Heart Rate', 'Max Heart Rate'
  # ].freeze

  attr_accessor :team, :metric, :start_date, :end_date, :channel_id

  def initialize(team, options = {})
    @team = team
    @metric = options[:metric]
    @start_date = options[:start_date]
    @end_date = options[:end_date]
    @channel_id = options[:channel_id]
    @aggregate = {}
  end

  def metric_field
    @metric_field ||= metric.downcase.gsub(' ', '_')
  end

  def aggreate_options(activity_type = nil)
    aggreate_options = { team_id: team.id, _type: 'UserActivity' }
    aggreate_options.merge!('type' => activity_type) if activity_type
    aggreate_options.merge!('channel_messages.channel' => channel_id) if channel_id
    if start_date && end_date
      aggreate_options.merge!('start_date' => { '$gte' => start_date, '$lte' => end_date })
    elsif start_date
      aggreate_options.merge!('start_date' => { '$gte' => start_date })
    elsif end_date
      aggreate_options.merge!('start_date' => { '$lte' => end_date })
    end
    aggreate_options
  end

  def aggregate!(activity_type = nil)
    @aggregate[activity_type || '*'] ||= begin
      raise SlackStrava::Error, "Missing value. Expected one of #{MEASURABLE_VALUES.or}." unless metric && !metric.blank?
      raise SlackStrava::Error, "Invalid value: #{metric}. Expected one of #{MEASURABLE_VALUES.or}." unless MEASURABLE_VALUES.map(&:downcase).include?(metric.downcase)
      raise SlackStrava::Error, 'Invalid date range. End date cannot be before start date.' if @start_date && @end_date && @start_date > @end_date

      UserActivity.collection.aggregate(
        [
          { '$match': aggreate_options(activity_type) },
          {
            '$group' => {
              _id: { user_id: '$user_id', type: '$type' },
              metric_field => { '$sum' => metric_field == 'count' ? 1 : "$#{metric_field}" }
            }
          },
          {
            '$setWindowFields': {
              sortBy: { metric_field => -1 },
              output: {
                rank: { '$denseRank': {} }
              }
            }
          }
        ]
      )
    end
  end

  def find(user_id, activity_type)
    position = aggregate!(activity_type).find_index do |row|
      row[:_id][:user_id] == user_id
    end

    position ? position + 1 : nil
  end

  def to_s
    top = aggregate!.map { |row|
      next unless row[metric_field].positive?

      Row.new(
        team: team,
        user: team.users.find(row[:_id][:user_id]),
        type: row[:_id][:type],
        field: metric_field,
        value: row[metric_field],
        rank: row[:rank]
      ).to_s
    }.compact
    if top.any?
      top.join("\n")
    else
      [
        'There are no activities',
        metric_field == 'count' ? nil : "with #{metric.downcase}",
        start_date && end_date ? "between #{start_date.to_fs(:long)} and #{end_date.to_fs(:long)}" : nil,
        start_date && end_date.nil? ? "after #{start_date.to_fs(:long)}" : nil,
        start_date.nil? && end_date ? "before #{end_date.to_fs(:long)}" : nil,
        'in this channel.'
      ].compact.join(' ')
    end
  end
end
