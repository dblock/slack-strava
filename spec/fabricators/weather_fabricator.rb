Fabricator(:weather) do
  initialize_with do
    Weather.new(JSON.parse(File.read(File.join(__dir__, 'one_call_weather.json')))['current'])
  end
end
