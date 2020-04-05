require 'spec_helper'

describe TeamStats do
  let(:team) { Fabricate(:team) }
  before do
    allow_any_instance_of(Map).to receive(:update_png!)
  end
  context 'with no activities' do
    let(:stats) { team.stats }
    context '#stats' do
      it 'aggregates stats' do
        expect(stats.count).to eq 0
      end
    end
    context '#to_slack' do
      it 'defaults to no activities' do
        expect(stats.to_slack).to eq({ text: 'There are no activities in this channel.' })
      end
    end
  end
  context 'with activities' do
    let!(:user1) { Fabricate(:user, team: team) }
    let!(:user2) { Fabricate(:user, team: team) }
    let!(:club) { Fabricate(:club, team: team) }
    let!(:swim_activity) { Fabricate(:swim_activity, user: user2) }
    let!(:ride_activity1) { Fabricate(:ride_activity, user: user1) }
    let!(:ride_activity2) { Fabricate(:ride_activity, user: user1) }
    let!(:club_activity) { Fabricate(:club_activity, club: club) }
    let!(:activity1) { Fabricate(:user_activity, user: user1) }
    let!(:activity2) { Fabricate(:user_activity, user: user1) }
    let!(:activity3) { Fabricate(:user_activity, user: user2) }
    context '#stats' do
      let(:stats) { team.stats }
      it 'returns stats sorted by count' do
        expect(stats.keys).to eq %w[Run Ride Swim]
        expect(stats.values.map(&:count)).to eq [4, 2, 1]
      end
      it 'aggregates stats' do
        expect(stats['Ride'].to_h).to eq(
          {
            distance: [ride_activity1, ride_activity2].map(&:distance).compact.sum,
            moving_time: [ride_activity1, ride_activity2].map(&:moving_time).compact.sum,
            elapsed_time: [ride_activity1, ride_activity2].map(&:elapsed_time).compact.sum,
            pr_count: 0,
            calories: 0,
            total_elevation_gain: 0
          }
        )
        expect(stats['Run'].to_h).to eq(
          {
            distance: [activity1, activity2, activity3, club_activity].map(&:distance).compact.sum,
            moving_time: [activity1, activity2, activity3, club_activity].map(&:moving_time).compact.sum,
            elapsed_time: [activity1, activity2, activity3, club_activity].map(&:elapsed_time).compact.sum,
            pr_count: [activity1, activity2, activity3, club_activity].map(&:pr_count).compact.sum,
            calories: [activity1, activity2, activity3, club_activity].map(&:calories).compact.sum,
            total_elevation_gain: [activity1, activity2, activity3, club_activity].map(&:total_elevation_gain).compact.sum
          }
        )
        expect(stats['Swim'].to_h).to eq(
          {
            distance: swim_activity.distance,
            moving_time: swim_activity.moving_time,
            elapsed_time: swim_activity.elapsed_time,
            pr_count: 0,
            calories: 0,
            total_elevation_gain: 0
          }
        )
      end
      context 'with activities from another team' do
        let!(:another_activity) { Fabricate(:user_activity, user: user1) }
        let!(:another_team_activity) { Fabricate(:user_activity, user: Fabricate(:user, team: Fabricate(:team))) }
        it 'does not include that activity' do
          expect(stats.values.map(&:count)).to eq [5, 2, 1]
        end
      end
    end
    context '#to_slack' do
      let(:stats) { team.stats }
      it 'includes all activities' do
        expect(stats.to_slack[:attachments].count).to eq(3)
      end
    end
  end
  context 'with activities across multiple channels' do
    let!(:user) { Fabricate(:user, team: team) }
    let!(:user_activity) { Fabricate(:user_activity, user: user) }
    let!(:club1) { Fabricate(:club, team: team, channel_id: 'channel1') }
    let!(:club1_activity) { Fabricate(:club_activity, club: club1) }
    let!(:club2) { Fabricate(:club, team: team, channel_id: 'channel2') }
    let!(:club2_activity) { Fabricate(:club_activity, club: club2) }
    context '#stats' do
      context 'all channels' do
        let!(:stats) { team.stats }
        let!(:activities) { [user_activity, club1_activity, club2_activity] }
        it 'returns stats for all activities' do
          expect(stats['Run'].to_h).to eq(
            {
              distance: activities.map(&:distance).compact.sum,
              moving_time: activities.map(&:moving_time).compact.sum,
              elapsed_time: activities.map(&:elapsed_time).compact.sum,
              pr_count: activities.map(&:pr_count).compact.sum,
              calories: activities.map(&:calories).compact.sum,
              total_elevation_gain: activities.map(&:total_elevation_gain).compact.sum
            }
          )
        end
      end
      context 'in channel with bragged club activity' do
        before do
          allow_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).and_return(ts: 'ts')
          club1_activity.brag!
        end
        context 'stats' do
          let(:stats) { team.stats(channel_id: club1.channel_id) }
          let(:activities) { [club1_activity] }
          it 'returns stats for all activities' do
            expect(stats['Run'].to_h).to eq(
              {
                distance: activities.map(&:distance).compact.sum,
                moving_time: activities.map(&:moving_time).compact.sum,
                elapsed_time: activities.map(&:elapsed_time).compact.sum,
                pr_count: activities.map(&:pr_count).compact.sum,
                calories: activities.map(&:calories).compact.sum,
                total_elevation_gain: activities.map(&:total_elevation_gain).compact.sum
              }
            )
          end
        end
      end
      context 'in channel with bragged user activity' do
        before do
          allow_any_instance_of(Team).to receive(:slack_channels).and_return(['id' => club1_activity.club.channel_id])
          allow_any_instance_of(User).to receive(:user_in_channel?).and_return(true)
          allow_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).and_return(ts: 'ts')
          user_activity.brag!
        end
        context 'stats' do
          let(:stats) { team.stats(channel_id: club1_activity.club.channel_id) }
          let(:activities) { [user_activity] }
          it 'returns stats for all activities' do
            expect(stats['Run'].to_h).to eq(
              {
                distance: activities.map(&:distance).compact.sum,
                moving_time: activities.map(&:moving_time).compact.sum,
                elapsed_time: activities.map(&:elapsed_time).compact.sum,
                pr_count: activities.map(&:pr_count).compact.sum,
                calories: activities.map(&:calories).compact.sum,
                total_elevation_gain: activities.map(&:total_elevation_gain).compact.sum
              }
            )
          end
        end
      end
      context 'in channel with bragged user and club activities' do
        before do
          allow_any_instance_of(Team).to receive(:slack_channels).and_return(['id' => club1_activity.club.channel_id])
          allow_any_instance_of(User).to receive(:user_in_channel?).and_return(true)
          allow_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).and_return(ts: 'ts')
          club1_activity.brag!
          user_activity.brag!
        end
        context 'stats' do
          let(:stats) { team.stats(channel_id: club1.channel_id) }
          let(:activities) { [user_activity, club1_activity] }
          it 'returns stats for all activities' do
            expect(stats['Run'].to_h).to eq(
              {
                distance: activities.map(&:distance).compact.sum,
                moving_time: activities.map(&:moving_time).compact.sum,
                elapsed_time: activities.map(&:elapsed_time).compact.sum,
                pr_count: activities.map(&:pr_count).compact.sum,
                calories: activities.map(&:calories).compact.sum,
                total_elevation_gain: activities.map(&:total_elevation_gain).compact.sum
              }
            )
          end
        end
      end
    end
  end
end
