require 'spec_helper'

describe SystemStats do
  let(:stats) { SystemStats.aggregate! }
  before do
    allow_any_instance_of(Map).to receive(:update_png!)
  end
  context 'aggregate!' do
    it 'creates a record' do
      expect { 2.times { SystemStats.aggregate! } }.to change(SystemStats, :count).by(2)
    end
  end
  context 'latest_or_aggregate!' do
    it 'creates one record' do
      expect { 2.times { SystemStats.latest_or_aggregate! } }.to change(SystemStats, :count).by(1)
    end
    it 'creates another record 24 hours later' do
      SystemStats.aggregate!
      Timecop.travel(Time.now + 1.day) do
        expect { SystemStats.latest_or_aggregate! }.to change(SystemStats, :count).by(1)
      end
      Timecop.travel(Time.now + 1.day + 1.hour) do
        expect { SystemStats.latest_or_aggregate! }.to_not change(SystemStats, :count)
      end
    end
  end
  context 'with no teams' do
    it 'zero' do
      expect(stats.teams_count).to eq 0
      expect(stats.active_teams_count).to eq 0
      expect(stats.connected_users_count).to eq 0
      expect(stats.total_distance_in_miles).to eq 0.0
      expect(stats.total_distance_in_miles_s).to be nil
    end
  end
  context 'with a team' do
    let!(:team) { Fabricate(:team) }
    it 'one team' do
      expect(stats.teams_count).to eq 1
      expect(stats.active_teams_count).to eq 1
      expect(stats.connected_users_count).to eq 0
      expect(stats.total_distance_in_miles).to eq 0.0
      expect(stats.total_distance_in_miles_s).to be nil
    end
  end
  context 'with activities' do
    let!(:team) { Fabricate(:team) }
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
    it 'aggregates stats' do
      expect(stats.teams_count).to eq 1
      expect(stats.active_teams_count).to eq 1
      expect(stats.connected_users_count).to eq 0
      expect(stats.total_distance_in_miles).to_not eq 0
      expect(stats.total_distance_in_miles_s).to match(/\d+.\d+ miles/)
    end
  end
end
