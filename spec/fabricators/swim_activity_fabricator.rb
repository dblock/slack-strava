Fabricator(:swim_activity, class_name: :user_activity) do
  strava_id { Fabricate.sequence(:user_id) { |i| "12345677892806#{i}" } }
  user { Fabricate.build(:user) }
  type 'Swim'
  name { Faker::Internet.user_name }
  start_date { DateTime.parse('2018-02-20T18:02:13Z') }
  start_date_local { DateTime.parse('2018-02-20T10:02:13Z') }
  distance 1874.5
  moving_time 2220
  elapsed_time 2220
  average_speed 0.844
  before_validation do
    self.team ||= user.team
  end
end
