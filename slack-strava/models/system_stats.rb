class SystemStats
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  field :teams_count, type: Integer
  field :active_teams_count, type: Integer
  field :connected_users_count, type: Integer
  field :total_distance_in_miles, type: Float

  def self.latest_or_aggregate!(_dt = 24.hours)
    latest_stats = latest
    return latest_stats if latest_stats && latest_stats.created_at + 24.hours > Time.now.utc

    aggregate!
  end

  def self.aggregate!
    create!(
      teams_count: Team.count,
      active_teams_count: Team.active.count,
      connected_users_count: User.connected_to_strava.count,
      total_distance_in_miles: Activity.sum(:distance) * 0.00062137
    )
  end

  def self.latest
    desc(:created_at).first
  end

  def total_distance_in_miles_s
    distance = total_distance_in_miles
    return unless distance&.positive?

    format('%.2f miles', distance)
  end
end
