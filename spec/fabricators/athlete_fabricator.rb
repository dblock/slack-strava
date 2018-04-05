Fabricator(:athlete) do
  athlete_id { Fabricate.sequence(:athlete_id) { |i| "7892806#{i}" } }
  username { Faker::Internet.user_name }
  firstname { Faker::Name.first_name }
  lastname { Faker::Name.last_name }
  profile { Faker::Avatar.image }
  profile_medium { Faker::Avatar.image }
end
