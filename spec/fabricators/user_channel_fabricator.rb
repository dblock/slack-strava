Fabricator(:user_channel) do
  user { Fabricate(:user) }
  channel_id { Fabricate.sequence(:channel_id) { |i| "C#{i}" } }
  channel_name { Faker::Internet.slug }
  before_create do
    self.team ||= user.team
  end
end
