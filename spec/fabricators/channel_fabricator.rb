Fabricator(:channel) do
  team { Fabricate(:team) }
  channel_id { Fabricate.sequence(:channel_id) { |i| "C#{i}" } }
  channel_name { Faker::Internet.slug }
  activity_types { [] }
end
