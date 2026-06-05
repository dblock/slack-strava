require 'spec_helper'

describe Club do
  let(:team) { Fabricate(:team) }
  let!(:club) { Fabricate(:club, team: team, strava_id: '43749', access_token: 'token', token_expires_at: Time.now + 1.day, token_type: 'Bearer') }

  context 'brag!' do
    let!(:activity) { Fabricate(:club_activity, club: club) }

    it 'brags the last unbragged activity' do
      expect_any_instance_of(ClubActivity).to receive(:brag!).and_return(
        [
          {
            ts: '1503435956.000247',
            channel: 'C1'
          }
        ]
      )
      results = club.brag!
      expect(results).to eq(
        [
          {
            ts: '1503435956.000247',
            channel: 'C1',
            activity: activity
          }
        ]
      )
    end
  end

  context 'sync_and_brag!' do
    it 'does not sync any activities' do
      allow_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).and_return('ts' => '1')
      expect { club.sync_and_brag! }.not_to change(club.activities, :count)
    end

    context 'upon creation' do
      it 'sends sync disabled notice' do
        expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with(
          hash_including(text: Club::SYNC_DISABLED_MESSAGE)
        ).once.and_return('ts' => '1')
        club.sync_and_brag!
        expect(club.reload.sync_disabled_informed_at).not_to be_nil
      end
    end

    context 'after initial sync_and_brag!' do
      before do
        club.update_attributes!(sync_disabled_informed_at: Time.now.utc)
      end

      it 'does not send sync disabled notice again' do
        expect_any_instance_of(Slack::Web::Client).not_to receive(:chat_postMessage).with(
          hash_including(text: Club::SYNC_DISABLED_MESSAGE)
        )
        club.sync_and_brag!
      end
    end

    it 'warns on error' do
      expect_any_instance_of(Logger).to receive(:warn).with(/unexpected error/)
      allow(club).to receive(:brag!).and_raise 'unexpected error'
      allow(club).to receive(:inform_sync_disabled!)
      expect { club.sync_and_brag! }.not_to raise_error
    end

    pending 'uses a lock'

    context 'sync disabled notice' do
      it 'sends the notice once' do
        expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with(
          hash_including(text: Club::SYNC_DISABLED_MESSAGE)
        ).once.and_return('ts' => '1')
        club.sync_and_brag!
        expect(club.reload.sync_disabled_informed_at).not_to be_nil
      end

      it 'does not send the notice a second time' do
        club.update_attributes!(sync_disabled_informed_at: Time.now.utc)
        expect_any_instance_of(Slack::Web::Client).not_to receive(:chat_postMessage).with(
          hash_including(text: Club::SYNC_DISABLED_MESSAGE)
        )
        club.sync_and_brag!
      end

      context 'with multiple clubs in the same channel' do
        let!(:club2) do
          Fabricate(:club, team: team, channel_id: club.channel_id, access_token: 'token',
                           token_expires_at: Time.now + 1.day, token_type: 'Bearer')
        end

        it 'sends the notice only once to the channel' do
          expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with(
            hash_including(text: Club::SYNC_DISABLED_MESSAGE)
          ).once.and_return('ts' => '1')
          club.sync_and_brag!
          expect(club.reload.sync_disabled_informed_at).not_to be_nil
          club2.sync_and_brag!
          expect(club2.reload.sync_disabled_informed_at).not_to be_nil
        end
      end

      it 'warns on Slack error sending sync disabled notice' do
        allow_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).and_raise(
          Slack::Web::Api::Errors::SlackError.new('channel_not_found')
        )
        expect_any_instance_of(Logger).to receive(:warn).with(/Failed to send sync disabled notice/)
        expect { club.sync_and_brag! }.not_to raise_error
        expect(club.reload.sync_disabled_informed_at).to be_nil
      end
    end

    context 'connected_to_strava' do
      let!(:club) { Fabricate(:club) }
      let!(:club_not_connected_to_strava) { Fabricate(:club, access_token: nil) }
      let!(:club_sync_activities_false) { Fabricate(:club, access_token: 'token', sync_activities: false) }

      it 'includes only clubs connected to strava with sync_activities' do
        expect(described_class.connected_to_strava.count).to eq 1
      end
    end
  end
end
