require 'spec_helper'

describe Club do
  let(:team) { Fabricate(:team) }
  let!(:club) { Fabricate(:club, team: team, strava_id: '43749', access_token: 'token', token_expires_at: Time.now + 1.day, token_type: 'Bearer') }

  context 'sync_last_strava_activity!', vcr: { allow_playback_repeats: true, cassette_name: 'strava/club_sync_last_strava_activity' } do
    it 'retrieves the last activity' do
      expect {
        club.sync_last_strava_activity!
      }.to change(club.activities, :count).by(1)
      activity = club.activities.last
      expect(activity.strava_id).to eq '777e317fcba7e7c78d6ad584fd7219d8'
      expect(activity.name).to eq 'Hard as fuck run home — tired + lots of aches '
    end

    it 'only saves the last activity once' do
      expect {
        2.times { club.sync_last_strava_activity! }
      }.to change(club.activities, :count).by(1)
    end

    it 'retrieves an incremental set of activities', vcr: { cassette_name: 'strava/club_sync_new_strava_activities' } do
      expect {
        club.sync_new_strava_activities!
      }.to change(club.activities, :count).by(8)
    end

    it 'retrieves an incremental set of activities skipping duplicates', vcr: { cassette_name: 'strava/club_sync_new_strava_activities' } do
      # first activity from the cassette
      club.activities.create!(team: club.team, strava_id: '777e317fcba7e7c78d6ad584fd7219d8')
      expect {
        club.sync_new_strava_activities!
      }.to change(club.activities, :count).by(7)
    end

    it 'updates the existing duplicate', vcr: { cassette_name: 'strava/club_sync_new_strava_activities' } do
      activity = club.activities.create!(team: club.team, strava_id: '777e317fcba7e7c78d6ad584fd7219d8')
      tt = activity.reload.updated_at.utc
      Timecop.travel(Time.now + 1.hour)
      club.sync_new_strava_activities!
      expect(activity.reload.updated_at.utc.to_i).not_to eq(tt.to_i)
    end

    context 'with two club channels' do
      let!(:club2) { Fabricate(:club, team: team, strava_id: '43749', channel_id: '1HNTD0CW', channel_name: 'testing', access_token: 'token', token_expires_at: Time.now + 1.day, token_type: 'Bearer') }

      it 'retrieves the last activity and stores it twice' do
        expect {
          club.sync_last_strava_activity!
        }.to change(club.activities, :count).by(1)
        expect {
          club2.sync_last_strava_activity!
        }.to change(club2.activities, :count).by(1)
        expect(club.activities.count).to eq(1)
        expect(club2.activities.count).to eq(1)
      end

      it 'only saves the last activity once per club' do
        expect {
          2.times { club.sync_last_strava_activity! }
        }.to change(club.activities, :count).by(1)
        expect {
          2.times { club2.sync_last_strava_activity! }
        }.to change(club2.activities, :count).by(1)
        expect(club.activities.count).to eq(1)
        expect(club2.activities.count).to eq(1)
      end

      it 'retrieves an incremental set of activities', vcr: { cassette_name: 'strava/club_sync_new_strava_activities', allow_playback_repeats: true } do
        expect {
          club.sync_new_strava_activities!
        }.to change(club.activities, :count).by(8)
        expect {
          club2.sync_new_strava_activities!
        }.to change(club2.activities, :count).by(8)
      end

      it 'retrieves an incremental set of activities skipping duplicates', vcr: { cassette_name: 'strava/club_sync_new_strava_activities', allow_playback_repeats: true } do
        # first activity from the cassette
        club.activities.create!(team: club.team, strava_id: '777e317fcba7e7c78d6ad584fd7219d8')
        club2.activities.create!(team: club.team, strava_id: '777e317fcba7e7c78d6ad584fd7219d8')
        expect {
          club.sync_new_strava_activities!
        }.to change(club.activities, :count).by(7)
        expect {
          club2.sync_new_strava_activities!
        }.to change(club2.activities, :count).by(7)
      end

      it 'updates the existing duplicates', vcr: { cassette_name: 'strava/club_sync_new_strava_activities', allow_playback_repeats: true } do
        activity = club.activities.create!(team: club.team, strava_id: '777e317fcba7e7c78d6ad584fd7219d8')
        tt = activity.reload.updated_at.utc
        activity2 = club2.activities.create!(team: club.team, strava_id: '777e317fcba7e7c78d6ad584fd7219d8')
        tt2 = activity.reload.updated_at.utc
        Timecop.travel(Time.now + 1.hour)
        club.sync_new_strava_activities!
        expect(activity.reload.updated_at.utc.to_i).not_to eq(tt.to_i)
        expect(activity2.reload.updated_at.utc.to_i).to eq(tt2.to_i)
      end
    end

    ['Authorization Error', 'Forbidden'].each do |message|
      it 'disconnects club on auth failure' do
        allow(club.strava_client).to receive(:club_activities).and_raise(
          Strava::Errors::Fault.new(401, body: { 'message' => message, 'errors' => [] })
        )
        expect(club.team.slack_client).to receive(:chat_postMessage).with(
          club.to_slack.merge(
            text: 'There was an authorization problem. Please reconnect the club via /slava clubs.',
            channel: club.channel_id,
            as_user: true
          )
        ).and_return('ts' => 1)
        expect { club.sync_last_strava_activity! }.to raise_error Strava::Errors::Fault
        expect(club.access_token).to be_nil
        expect(club.token_type).to be_nil
        expect(club.refresh_token).to be_nil
        expect(club.token_expires_at).to be_nil
      end
    end
    it 'disables sync on 404' do
      expect(club.sync_activities?).to be true
      allow(club.strava_client).to receive(:club_activities).and_raise(
        Faraday::ResourceNotFound.new(404, body: { 'message' => 'Not Found', 'errors' => [] })
      )
      expect(club.team.slack_client).to receive(:chat_postMessage).with(
        hash_including(
          text: 'Your club can no longer be found on Strava. Please disconnect and reconnect it via /slava clubs.',
          channel: club.channel_id,
          as_user: true
        )
      ).and_return('ts' => 1)
      expect { club.sync_last_strava_activity! }.to raise_error Faraday::ResourceNotFound
      expect(club.sync_activities?).to be false
    end

    it 'disables sync on not_in_channel' do
      expect(club.sync_activities?).to be true
      allow(club.strava_client).to receive(:club_activities).and_raise(Slack::Web::Api::Errors::NotInChannel.new('not_in_channel'))
      expect { club.sync_last_strava_activity! }.to raise_error Slack::Web::Api::Errors::NotInChannel
      expect(club.sync_activities?).to be false
    end

    context 'without a refresh token (until October 2019)', vcr: { cassette_name: 'strava/refresh_access_token' } do
      before do
        club.update_attributes!(refresh_token: nil, token_expires_at: nil)
      end

      it 'refreshes access token using access token' do
        club.send(:strava_client)
        expect(club.refresh_token).to eq 'updated-refresh-token'
        expect(club.access_token).to eq 'updated-access-token'
        expect(club.token_expires_at).not_to be_nil
        expect(club.token_type).to eq 'Bearer'
      end
    end

    context 'with an expired refresh token', vcr: { cassette_name: 'strava/refresh_access_token' } do
      before do
        club.update_attributes!(refresh_token: 'refresh_token', token_expires_at: nil)
      end

      it 'refreshes access token' do
        club.send(:strava_client)
        expect(club.refresh_token).to eq 'updated-refresh-token'
        expect(club.access_token).to eq 'updated-access-token'
        expect(club.token_expires_at).not_to be_nil
        expect(club.token_type).to eq 'Bearer'
      end
    end
  end

  context 'brag!' do
    let!(:activity) { Fabricate(:club_activity, club: club) }

    it 'brags the last unbragged activity' do
      expect_any_instance_of(ClubActivity).to receive(:brag!).and_return(
        [
          ts: '1503435956.000247',
          channel: 'C1'
        ]
      )
      results = club.brag!
      expect(results).to eq(
        [
          ts: '1503435956.000247',
          channel: 'C1',
          activity: activity
        ]
      )
    end
  end

  context 'sync_and_brag!', vcr: { cassette_name: 'strava/club_sync_new_strava_activities', allow_playback_repeats: true } do
    context 'upon creation' do
      it 'syncs but does not brag' do
        expect_any_instance_of(Slack::Web::Client).not_to receive(:chat_postMessage)
        club.sync_and_brag!
      end
    end

    context 'after an initial sync' do
      before do
        club.sync_and_brag!
      end

      context 'with a new activity' do
        before do
          club.activities.desc(:_id).first.destroy
        end

        it 'syncs and brags' do
          expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).once
          club.sync_and_brag!
        end
      end
    end

    it 'warns on error' do
      expect_any_instance_of(Logger).to receive(:warn).with(/unexpected error/)
      allow(club).to receive(:sync_new_strava_activities!).and_raise 'unexpected error'
      expect { club.sync_and_brag! }.not_to raise_error
    end

    context 'rate limit exceeded' do
      let(:rate_limit_exceeded_error) { Strava::Errors::Fault.new(429, body: { 'message' => 'Rate Limit Exceeded', 'errors' => [{ 'resource' => 'Application', 'field' => 'rate limit', 'code' => 'exceeded' }] }) }

      it 'raises an exception' do
        allow(club).to receive(:sync_new_strava_activities!).and_raise rate_limit_exceeded_error
        expect { club.sync_and_brag! }.to raise_error(Strava::Errors::Fault, /Rate Limit Exceeded/)
      end
    end

    pending 'uses a lock'

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
