require 'spec_helper'

describe TeamLeaderboard do
  let!(:team) { Fabricate(:team) }

  before do
    allow_any_instance_of(Map).to receive(:update_png!)
  end

  context 'initialize' do
    it 'errors on no metric' do
      expect { TeamLeaderboard.new(team, metric: nil).aggregate! }.to raise_error SlackStrava::Error, "Missing value. Expected one of #{TeamLeaderboard::MEASURABLE_VALUES.or}."
    end

    it 'errors on empty metric' do
      expect { TeamLeaderboard.new(team, metric: '').aggregate! }.to raise_error SlackStrava::Error, "Missing value. Expected one of #{TeamLeaderboard::MEASURABLE_VALUES.or}."
    end

    it 'errors on invalid' do
      expect { TeamLeaderboard.new(team, metric: 'invalid').aggregate! }.to raise_error SlackStrava::Error, "Invalid value: invalid. Expected one of #{TeamLeaderboard::MEASURABLE_VALUES.or}."
    end

    it 'errors on multiple metrics' do
      expect { TeamLeaderboard.new(team, metric: 'Distance, Speed').aggregate! }.to raise_error SlackStrava::Error, "Invalid value: Distance, Speed. Expected one of #{TeamLeaderboard::MEASURABLE_VALUES.or}."
    end

    it 'errors on one invalid metric' do
      expect { TeamLeaderboard.new(team, metric: 'Distance, invalid').aggregate! }.to raise_error SlackStrava::Error, "Invalid value: Distance, invalid. Expected one of #{TeamLeaderboard::MEASURABLE_VALUES.or}."
    end

    it 'is case insensitive' do
      expect { TeamLeaderboard.new(team, metric: 'distance').aggregate! }.not_to raise_error
      expect { TeamLeaderboard.new(team, metric: 'pR CouNT').aggregate! }.not_to raise_error
    end
  end

  TeamLeaderboard::MEASURABLE_VALUES.each do |metric|
    context metric do
      let(:leaderboard) { TeamLeaderboard.new(team, metric: metric) }

      it 'returns no activities by default' do
        expect(leaderboard.to_s).to eq "There are no activities with #{metric} in this channel."
      end
    end
  end
  context 'with activities' do
    let(:user1) { Fabricate(:user, team: team) }
    let(:user2) { Fabricate(:user, team: team) }
    let!(:user1_activity_1) { Fabricate(:user_activity, user: user1, team: team) }
    let!(:user1_activity_2) { Fabricate(:user_activity, user: user1, team: team) }
    let!(:user1_activity_3) { Fabricate(:user_activity, user: user1, team: team) }
    let!(:user1_swim_activity_1) { Fabricate(:swim_activity, user: user1, team: team) }
    let!(:user1_swim_activity_2) { Fabricate(:swim_activity, user: user1, team: team) }
    let!(:user2_activity_1) { Fabricate(:user_activity, user: user2, team: team) }
    let!(:another_activity) { Fabricate(:user_activity, user: Fabricate(:user, team: Fabricate(:team))) }
    let!(:club_activity) { Fabricate(:club_activity, team: team) }

    TeamLeaderboard::MEASURABLE_VALUES.each do |metric|
      context metric do
        let(:leaderboard) { TeamLeaderboard.new(team, metric: metric) }

        it 'returns no activities by default' do
          expect(leaderboard.to_s).not_to be_blank
        end
      end
    end
    context 'distance leaderboard' do
      let(:leaderboard) { team.leaderboard(metric: 'Distance') }

      it 'aggregate!' do
        expect(leaderboard.aggregate!.to_a).to eq(
          [
            { '_id' => { 'user_id' => user1.id, 'type' => 'Run' }, 'distance' => user1_activity_1.distance + user1_activity_2.distance + user1_activity_3.distance, 'rank' => 1 },
            { '_id' => { 'user_id' => user2.id, 'type' => 'Run' }, 'distance' => user2_activity_1.distance, 'rank' => 2 },
            { '_id' => { 'user_id' => user1.id, 'type' => 'Swim' }, 'distance' => user1_swim_activity_1.distance + user1_swim_activity_2.distance, 'rank' => 3 }
          ]
        )
      end

      it 'to_s' do
        expect(leaderboard.to_s).to eq(
          [
            "1: #{user1.user_name} 🏃 #{format('%.2f', (user1_activity_1.distance + user1_activity_2.distance + user1_activity_3.distance) * 0.00062137)}mi",
            "2: #{user2.user_name} 🏃 #{format('%.2f', user2_activity_1.distance * 0.00062137)}mi",
            "3: #{user1.user_name} 🏊 #{format('%.1f', (user1_swim_activity_1.distance + user1_swim_activity_2.distance) * 1.09361)}yd"
          ].join("\n")
        )
      end
    end

    context 'count leaderboard' do
      let(:leaderboard) { team.leaderboard(metric: 'Count') }

      it 'aggregate!' do
        expect(leaderboard.aggregate!.to_a).to eq(
          [
            { '_id' => { 'user_id' => user1.id, 'type' => 'Run' }, 'count' => 3, 'rank' => 1 },
            { '_id' => { 'user_id' => user1.id, 'type' => 'Swim' }, 'count' => 2, 'rank' => 2 },
            { '_id' => { 'user_id' => user2.id, 'type' => 'Run' }, 'count' => 1, 'rank' => 3 }
          ]
        )
      end

      it 'to_s' do
        expect(leaderboard.to_s).to eq(
          [
            "1: #{user1.user_name} 🏃 3",
            "2: #{user1.user_name} 🏊 2",
            "3: #{user2.user_name} 🏃 1"
          ].join("\n")
        )
      end
    end

    context 'channel leaderboard' do
      before do
        user1_activity_1.update_attributes!(
          {
            channel_messages: [
              ChannelMessage.new(channel: 'channel1')
            ]
          }
        )
        user1_activity_2.update_attributes!({
                                              channel_messages: [
                                                ChannelMessage.new(channel: 'channel1'),
                                                ChannelMessage.new(channel: 'channel2')
                                              ]
                                            })
      end

      context 'channel1' do
        let(:leaderboard) { team.leaderboard(metric: 'Distance', channel_id: 'channel1') }

        it 'aggregate!' do
          expect(leaderboard.aggregate!.to_a).to eq(
            [
              { '_id' => { 'user_id' => user1.id, 'type' => 'Run' }, 'distance' => user1_activity_1.distance + user1_activity_2.distance, 'rank' => 1 }
            ]
          )
        end
      end

      context 'channel2' do
        let(:leaderboard) { team.leaderboard(metric: 'Distance', channel_id: 'channel2') }

        it 'aggregate!' do
          expect(leaderboard.aggregate!.to_a).to eq(
            [
              { '_id' => { 'user_id' => user1.id, 'type' => 'Run' }, 'distance' => user1_activity_1.distance, 'rank' => 1 }
            ]
          )
        end
      end
    end
  end
end
