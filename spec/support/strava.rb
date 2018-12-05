RSpec.configure do |config|
  config.before do
    ENV['STRAVA_CLIENT_ID'] ||= 'client-id'
    ENV['STRAVA_CLIENT_SECRET'] ||= 'client-secret'
  end
end
