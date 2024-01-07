require 'spec_helper'

describe ActivityFields do
  context '#parse_s' do
    it 'returns nil for nil' do
      expect(ActivityFields.parse_s(nil)).to be nil
    end
    it 'returns an empty set for an empty string' do
      expect(ActivityFields.parse_s('')).to eq([])
    end
    it 'returns None' do
      expect(ActivityFields.parse_s('none')).to eq([ActivityFields::NONE])
    end
    it 'returns Time' do
      expect(ActivityFields.parse_s('time')).to eq([ActivityFields::TIME])
    end
    it 'returns Elapsed Time' do
      expect(ActivityFields.parse_s('elapsed time')).to eq([ActivityFields::ELAPSED_TIME])
    end
    it 'returns Time and Elapsed Time' do
      expect(ActivityFields.parse_s('time, elapsed time')).to eq([ActivityFields::TIME, ActivityFields::ELAPSED_TIME])
    end
    it 'cannot combine None with other values' do
      expect { ActivityFields.parse_s('None, elapsed time') }.to raise_error SlackStrava::Error, 'None cannot be used with other fields.'
    end
    it 'cannot combine All with other values' do
      expect { ActivityFields.parse_s('All, elapsed time') }.to raise_error SlackStrava::Error, 'All cannot be used with other fields.'
    end
    it 'removes duplicates' do
      expect(ActivityFields.parse_s('elapsed time, Elapsed Time, Time')).to eq([ActivityFields::ELAPSED_TIME, ActivityFields::TIME])
    end
    it 'raise an error on an invalid value' do
      expect { ActivityFields.parse_s('invalid, elapsed time') }.to raise_error SlackStrava::Error, 'Invalid field: invalid, possible values are Default, All, None, Type, Distance, Time, Moving Time, Elapsed Time, Pace, Speed, Elevation, Max Speed, Heart Rate, Max Heart Rate, PR Count, Calories, Weather, Title, Description, Url, User, Athlete and Date.'
    end
    it 'raise an error on invalid fields' do
      expect { ActivityFields.parse_s('invalid, elapsed time, whatever') }.to raise_error SlackStrava::Error, 'Invalid fields: invalid and whatever, possible values are Default, All, None, Type, Distance, Time, Moving Time, Elapsed Time, Pace, Speed, Elevation, Max Speed, Heart Rate, Max Heart Rate, PR Count, Calories, Weather, Title, Description, Url, User, Athlete and Date.'
    end
  end
end
