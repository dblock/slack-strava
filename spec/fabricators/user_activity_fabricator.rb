Fabricator(:user_activity) do
  strava_id { Fabricate.sequence(:user_id) { |i| "12345677892806#{i}" } }
  user { Fabricate.build(:user) }
  type 'Run'
  name { Faker::Internet.user_name }
  start_date { DateTime.parse('2018-02-20T18:02:13Z') }
  start_date_local { DateTime.parse('2018-02-20T10:02:13Z') }
  distance 22_539.6
  moving_time 7586
  elapsed_time 7686
  average_speed 2.971
  total_elevation_gain 144.9
  max_speed 9.3
  average_heartrate 140.3
  max_heartrate 178
  pr_count 3
  calories 870.2
  map { Fabricate.build(:map) }
  weather { Fabricate.build(:weather) }
  before_validation do
    self.team ||= user.team
  end
  after_create do
    map&.save!
  end
end
