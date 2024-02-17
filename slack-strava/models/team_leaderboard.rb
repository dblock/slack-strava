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
      ["#{rank}:", user.user_name, emoji, send("#{field}_s")].join(' ').to_s
    end

    def count_s
      value
    end

    def method_missing(method, *args)
      if method.to_s == field
        value
      else
        super
      end
    end
  end

  MEASURABLE_VALUES = [
    'Count', 'Distance', 'Time', 'Moving Time', 'Elapsed Time', 'Elevation', 'PR Count', 'Calories'
  ].freeze

  # MIN_MAX_VALUES = [
  #   'Pace', 'Speed', 'Max Speed', 'Heart Rate', 'Max Heart Rate'
  # ].freeze

  attr_accessor :team, :metric, :channel_id

  def initialize(team, options = {})
    @team = team
    @metric = options[:metric]
    @channel_id = options[:channel_id]
  end

  def metric_field
    @metric_field ||= metric.downcase.underscore
  end

  def aggreate_options
    aggreate_options = { team_id: team.id }
    aggreate_options.merge!('channel_messages.channel' => channel_id) if channel_id
    aggreate_options
  end

  def aggregate!
    @aggregate ||= begin
      raise SlackStrava::Error, "Missing value. Expected one of #{MEASURABLE_VALUES.or}." unless metric && !metric.blank?
      raise SlackStrava::Error, "Invalid value: #{metric}. Expected one of #{MEASURABLE_VALUES.or}." unless MEASURABLE_VALUES.map(&:downcase).include?(metric.downcase)

      UserActivity.collection.aggregate(
        [
          { '$match': aggreate_options },
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

  def to_s
    top = aggregate!.map do |row|
      Row.new(
        team: team,
        user: team.users.find(row[:_id][:user_id]),
        type: row[:_id][:type],
        field: metric_field,
        value: row[metric_field],
        rank: row[:rank]
      ).to_s
    end
    top.any? ? top.join("\n") : 'No activities.'
  end
end
