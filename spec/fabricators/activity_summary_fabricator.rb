Fabricator(:activity_summary) do
  team { Team.first || Fabricate(:team) }
  type 'Run'
  count 8
  athlete_count 2
  stats do
    {
      distance: 22_539.6,
      moving_time: 7586,
      elapsed_time: 7686,
      total_elevation_gain: 144.9,
      pr_count: 3,
      calories: 870.2,
      type: 'Run'
    }
  end
end
