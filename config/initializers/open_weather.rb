OpenWeather.configure do |config|
  config.api_key = ENV.fetch('OPEN_WEATHER_APP_ID', nil)
end
