Fabricator(:activity) do
  strava_id { Fabricate.sequence(:user_id) { |i| "12345677892806#{i}" } }
  type 'Run'
  name { Faker::Internet.user_name }
  start_date { DateTime.parse('2018-02-20T18:02:13Z') }
  start_date_local { DateTime.parse('2018-02-20T10:02:13Z') }
  distance 22_539.6
  moving_time 7586.0
  average_speed 2.971
  map { |a| Fabricate(:map, activity: a) }
end
