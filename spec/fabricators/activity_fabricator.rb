Fabricator(:activity) do
  strava_id { Fabricate.sequence(:user_id) { |i| "12345677892806#{i}" } }
  name { Faker::Internet.user_name }
  start_date { DateTime.parse('2018-02-20T18:02:13Z') }
  start_date_local { DateTime.parse('2018-02-20T10:02:13Z') }
  distance 28_099
  moving_time 4207
  average_speed 6.679
  map { Fabricate(:map) }
end
