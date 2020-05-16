Fabricator(:one_call_historical_weather, class_name: 'OpenWeather::Models::OneCall::Weather') do
  initialize_with do
    OpenWeather::Models::OneCall::Weather.new(JSON.parse(File.read(File.join(__dir__, 'one_call_historical_weather.json'))))
  end
end
