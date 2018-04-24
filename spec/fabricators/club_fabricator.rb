Fabricator(:club) do
  strava_id { Fabricate.sequence(:club_id) { |i| "43749#{i}" } }
  name { Faker::Company.name }
  logo { Faker::Avatar.image }
  city { Faker::Address.city }
  state { Faker::Address.state }
  country { Faker::Address.country }
  member_count 146
  url { Faker::Internet.slug }
  description { Faker::Company.catch_phrase }
  access_token 'token'
  token_type 'Bearer'
  channel_id '0HNTD0CW'
  channel_name 'running'
end
