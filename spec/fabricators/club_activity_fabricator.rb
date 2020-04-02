Fabricator(:club_activity) do
  strava_id { Fabricate.sequence(:user_id) { |i| "12345677892806#{i}" } }
  club { Fabricate.build(:club) }
  type 'Run'
  name { Faker::Internet.user_name }
  athlete_name { Faker::Name.name }
  distance 22_539.6
  moving_time 7586
  elapsed_time 7686
  total_elevation_gain 144.9
  average_speed 2.971
  before_validation do
    self.team ||= club.team
  end
end
