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
                bragged_at: 1.day.ago,
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
        total_elevation_gain: user_activity.total_elevation_gain,
        team: user_activity.team
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
    it 'does not find a similar user activity bragged a long time ago' do
      user_activity.set(bragged_at: 1.week.ago)
      expect(Activity.new(user_activity_data).bragged_in?('channel1')).to be false
    end
    it 'does not find a similar user activity bragged in a different team' do
      expect(Activity.new(user_activity_data.merge(team: Fabricate(:team))).bragged_in?('channel1')).to be false
    end
  end
  context 'privately_bragged?' do
    context 'private activity' do
      let!(:user_activity) do
        Fabricate(:user_activity,
                  private: true,
                  map: nil,
                  bragged_at: 1.day.ago,
                  channel_messages: [])
      end
      let(:user_activity_data) do
        {
          private: true,
          distance: user_activity.distance,
          moving_time: user_activity.moving_time,
          elapsed_time: user_activity.elapsed_time,
          total_elevation_gain: user_activity.total_elevation_gain,
          team: user_activity.team
        }
      end
      it 'finds a similar user activity' do
        expect(Activity.new(user_activity_data).privately_bragged?).to be true
      end
      it 'does not find a similar public user activity' do
        user_activity.set(private: false)
        expect(Activity.new(user_activity_data).privately_bragged?).to be false
      end
      it 'finds a similar user activity with everyone visibility' do
        user_activity.set(visibility: 'everyone')
        expect(Activity.new(user_activity_data).privately_bragged?).to be true
      end
      it 'does not find a dissimilar private activity' do
        expect(Activity.new(user_activity_data.merge(distance: -1)).privately_bragged?).to be false
      end
      it 'does not find a similar private user activity bragged a long time ago' do
        user_activity.set(bragged_at: 1.week.ago)
        expect(Activity.new(user_activity_data).privately_bragged?).to be false
      end
      it 'does not find a similar private user activity in a different team' do
        expect(Activity.new(user_activity_data.merge(team: Fabricate(:team))).privately_bragged?).to be false
      end
    end
    context 'visibility' do
      let!(:user_activity) do
        Fabricate(:user_activity,
                  map: nil,
                  bragged_at: 1.day.ago,
                  channel_messages: [])
      end
      let(:user_activity_data) do
        {
          distance: user_activity.distance,
          moving_time: user_activity.moving_time,
          elapsed_time: user_activity.elapsed_time,
          total_elevation_gain: user_activity.total_elevation_gain,
          team: user_activity.team
        }
      end
      it 'finds a similar only_me user activity' do
        user_activity.set(visibility: 'only_me')
        expect(Activity.new(user_activity_data).privately_bragged?).to be true
      end
      it 'finds a similar followers_only user activity' do
        user_activity.set(visibility: 'followers_only')
        expect(Activity.new(user_activity_data).privately_bragged?).to be true
      end
      it 'does not find a similar everyone user activity' do
        user_activity.set(visibility: 'everyone')
        expect(Activity.new(user_activity_data).privately_bragged?).to be false
      end
      it 'does not find a dissimilar private activity' do
        user_activity.set(visibility: 'only_me')
        expect(Activity.new(user_activity_data.merge(distance: -1)).privately_bragged?).to be false
      end
      it 'does not find a similar private user activity bragged a long time ago' do
        user_activity.set(visibility: 'only_me')
        user_activity.set(bragged_at: 1.week.ago)
        expect(Activity.new(user_activity_data).privately_bragged?).to be false
      end
      it 'does not find a similar private user activity in a different team' do
        user_activity.set(visibility: 'only_me')
        expect(Activity.new(user_activity_data.merge(team: Fabricate(:team))).privately_bragged?).to be false
      end
    end
  end
  context 'access changes' do
    before do
      allow(HTTParty).to receive_message_chain(:get, :body).and_return('PNG')
    end
    describe 'privacy changes' do
      context 'a private, bragged activity that was not posted to any channels' do
        let!(:activity) { Fabricate(:user_activity, private: true, bragged_at: Time.now.utc) }
        it 'resets bragged_at' do
          activity.update_attributes!(private: false)
          expect(activity.reload.bragged_at).to be_nil
        end
      end
      context 'a private, bragged activity a long time ago that was not posted to any channels' do
        let!(:activity) { Fabricate(:user_activity, private: true, bragged_at: 1.week.ago) }
        it 'does not reset bragged_at' do
          activity.update_attributes!(private: false)
          expect(activity.reload.bragged_at).to_not be_nil
        end
      end
      context 'a private, bragged activity that was posted to a channel' do
        let!(:activity) { Fabricate(:user_activity, private: true, bragged_at: Time.now.utc, channel_messages: [ChannelMessage.new(channel: 'c1')]) }
        it 'does not reset bragged_at' do
          activity.update_attributes!(private: false)
          expect(activity.reload.bragged_at).to_not be_nil
        end
      end
    end
    describe 'visibility changes' do
      context 'bragged activity that was not posted to any channels' do
        let!(:activity) { Fabricate(:user_activity, visibility: 'only_me', bragged_at: Time.now.utc) }
        it 'resets bragged_at' do
          activity.update_attributes!(visibility: 'everyone')
          expect(activity.reload.bragged_at).to be_nil
        end
      end
      context 'bragged activity a long time ago that was not posted to any channels' do
        let!(:activity) { Fabricate(:user_activity, visibility: 'only_me', bragged_at: 1.week.ago) }
        it 'does not reset bragged_at' do
          activity.update_attributes!(visibility: 'everyone')
          expect(activity.reload.bragged_at).to_not be_nil
        end
      end
      context 'bragged activity that was posted to a channel' do
        let!(:activity) { Fabricate(:user_activity, visibility: 'only_me', bragged_at: Time.now.utc, channel_messages: [ChannelMessage.new(channel: 'c1')]) }
        it 'does not reset bragged_at' do
          activity.update_attributes!(visibility: 'everyone')
          expect(activity.reload.bragged_at).to_not be_nil
        end
      end
    end
  end
end
