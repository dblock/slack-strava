require 'spec_helper'

describe Activity do
  context '#pace_per_mile_s' do
    it 'rounds up 60 seconds' do
      expect(Activity.new(average_speed: 3.354).pace_per_mile_s).to eq '8m00s/mi'
    end
  end
  context '#==' do
    let(:club_activity) { Fabricate(:club_activity) }
    let(:swim_activity) { Fabricate(:swim_activity) }
    it 'same object' do
      expect(club_activity).to eq club_activity
    end
    it 'different instance' do
      expect(club_activity).to eq Fabricate(:club_activity)
      expect(club_activity).to eq club_activity.dup
      expect(swim_activity).to_not eq club_activity
      expect(club_activity).to_not eq swim_activity
    end
    context 'same data' do
      let(:data) do
        {
          distance: 1,
          moving_time: 2,
          elapsed_time: 3,
          total_elevation_gain: 4
        }
      end
      let(:activity) { Activity.new(data) }
      it 'equals for different instances' do
        expect(Activity.new(data)).to eq activity
        expect(ClubActivity.new(data)).to eq activity
        expect(activity).to eq Activity.new(data)
        expect(activity).to eq ClubActivity.new(data)
      end
      it 'is different with different data' do
        expect(Activity.new(data.merge(distance: 0))).to_not eq activity
        expect(Activity.new(data.merge(moving_time: 0))).to_not eq activity
        expect(Activity.new(data.merge(elapsed_time: 0))).to_not eq activity
        expect(Activity.new(data.merge(total_elevation_gain: 0))).to_not eq activity
      end
    end
    it 'different object' do
      expect(swim_activity).to_not eq Object.new
    end
  end
  context 'bragged_in?' do
    let!(:user_activity) do
      Fabricate(:user_activity,
                map: nil,
                channel_messages: [
                  ChannelMessage.new(channel: 'channel1'),
                  ChannelMessage.new(channel: 'channel2')
                ])
    end
    let(:user_activity_data) do
      {
        distance: user_activity.distance,
        moving_time: user_activity.moving_time,
        elapsed_time: user_activity.elapsed_time,
        total_elevation_gain: user_activity.total_elevation_gain
      }
    end
    it 'finds a similar user activity' do
      expect(Activity.new(user_activity_data).bragged_in?('channel1')).to be true
    end
    it 'does not find a similar user activity bragged in a different channel' do
      expect(Activity.new(user_activity_data).bragged_in?('another')).to be false
    end
    it 'does not find a dissimilar activity' do
      expect(Activity.new(user_activity_data.merge(distance: -1)).bragged_in?('channel2')).to be false
    end
  end
end
