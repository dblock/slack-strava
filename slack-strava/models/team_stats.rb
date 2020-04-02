class TeamStats
  extend Forwardable

  attr_reader :team
  attr_reader :stats

  def initialize(team)
    @team = team
    aggregate!
  end

  def_delegators :@stats, :each, :[], :count, :size, :keys, :values, :any?, :map

  def to_slack
    any? ? {
      attachments: values.map(&:to_slack_attachment)
    } : { text: 'There are no activities.' }
  end

  private

  def aggregate!
    @stats = Hash[
      Activity.collection.aggregate(
        [
          { '$match' => { team_id: team.id } },
          { '$group' => {
            _id: { type: { '$ifNull' => ['$type', 'unknown'] } },
            count: { '$sum' => 1 },
            distance: { '$sum' => '$distance' },
            elapsed_time: { '$sum' => '$elapsed_time' },
            moving_time: { '$sum' => '$moving_time' },
            pr_count: { '$sum' => '$pr_count' },
            calories: { '$sum' => '$calories' },
            total_elevation_gain: { '$sum' => '$total_elevation_gain' }
          } }
        ]
      ).map do |row|
        type = row['_id']['type']
        [type, ActivitySummary.new(
          team: team,
          type: type,
          count: row['count'],
          athlete_count: team.activities.where(type: type).distinct(:user_id).count,
          stats: Hashie::Mash.new(row.except('_id').except('count'))
        )]
      end
    ]
  end
end
