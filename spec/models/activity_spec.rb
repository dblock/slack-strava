require 'spec_helper'

describe Activity do
  context '#pace_per_mile_s' do
    it 'rounds up 60 seconds' do
      expect(Activity.new(average_speed: 3.354).pace_per_mile_s).to eq '8m00s/mi'
    end
  end
end
