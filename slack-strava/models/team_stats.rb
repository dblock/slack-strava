class TeamStats
  extend Forwardable
  include DateHelper

  attr_reader :team, :stats, :options

  def initialize(team, options = {})
    @team = team
    @options = options.dup
    aggregate!
  end

  def_delegators :@stats, :each, :[], :count, :size, :keys, :values, :any?, :map

  def start_date
    options[:start_date]
  end

  def end_date
    options[:end_date]
  end

  def period_s
    if start_date && end_date
      "between #{format_date(start_date)} and #{format_date(end_date)}"
    elsif start_date
      "after #{format_date(start_date)}"
    elsif end_date
      "before #{format_date(end_date)}"
    end
  end

  def to_slack
    if any?
      result = { attachments: values.map(&:to_slack) }
      result[:text] = "Activities #{period_s}." if period_s
      result
    else
      period_label = period_s ? " #{period_s}" : ''
      { text: "There are no activities#{period_label} in this channel." }
    end
  end

  private

  def aggreate_options
    aggreate_options = { team_id: team.id }
    aggreate_options.merge!('channel_messages.channel' => options[:channel_id]) if options.key?(:channel_id)
    if start_date && end_date
      aggreate_options.merge!('start_date' => { '$gte' => start_date, '$lte' => end_date })
    elsif start_date
      aggreate_options.merge!('start_date' => { '$gte' => start_date })
    elsif end_date
      aggreate_options.merge!('start_date' => { '$lte' => end_date })
    end
    aggreate_options
  end

  def aggregate!
    @stats = Activity.collection.aggregate(
      [
        { '$match' => aggreate_options },
        {
          '$group' => {
            _id: { type: { '$ifNull' => ['$type', 'unknown'] } },
            count: { '$sum' => 1 },
            distance: { '$sum' => '$distance' },
            elapsed_time: { '$sum' => '$elapsed_time' },
            moving_time: { '$sum' => '$moving_time' },
            pr_count: { '$sum' => '$pr_count' },
            calories: { '$sum' => '$calories' },
            total_elevation_gain: { '$sum' => '$total_elevation_gain' }
          }
        },
        { '$sort' => { count: -1 } }
      ]
    ).to_h do |row|
      type = row['_id']['type']
      [type, ActivitySummary.new(
        team: team,
        type: type,
        count: row['count'],
        athlete_count: team.activities.where(type: type).distinct(:user_id).count,
        stats: Hashie::Mash.new(row.except('_id').except('count'))
      )]
    end
  end
end
