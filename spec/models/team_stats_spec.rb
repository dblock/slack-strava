require 'spec_helper'

describe TeamStats do
  let(:team) { Fabricate(:team) }
  let(:stats) { team.stats }
  before do
    allow_any_instance_of(Map).to receive(:update_png!)
  end
  context 'with no activities' do
    context '#stats' do
      it 'aggregates stats' do
        expect(stats.count).to eq 0
      end
    end
    context '#to_slack' do
      it 'defaults to no activities' do
        expect(stats.to_slack).to eq({ text: 'There are no activities.' })
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
      it 'includes all activities' do
        expect(stats.to_slack[:attachments].count).to eq(3)
      end
    end
  end
end
