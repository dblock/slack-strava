Fabricator(:alpine_ski_activity, class_name: :user_activity) do
  strava_id { Fabricate.sequence(:user_id) { |i| "12345677892806#{i}" } }
  user { Fabricate.build(:user) }
  type 'AlpineSki'
  name { Faker::Internet.user_name }
  start_date { DateTime.parse('2025-01-29T08:07:26Z') }
  start_date_local { DateTime.parse('2025-01-29T09:07:26Z') }
  distance 23_100.0
  moving_time 4554
  elapsed_time 20_427
  before_create do
    self.team ||= user.team
  end
end
