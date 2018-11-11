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
      expect(activity.strava_id).to eq '5eda0300f784214d9981ca60e9a730e4'
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
    it 'disconnects club on auth failure' do
      allow(club.send(:strava_client)).to receive(:list_club_activities).and_raise(
        Strava::Api::V3::ClientError.new(401, '{"message":"Authorization Error","errors":[]}')
      )
      expect { club.sync_last_strava_activity! }.to raise_error Strava::Api::V3::ClientError
      expect(club.access_token).to be nil
      expect(club.token_type).to be nil
      expect(club.refresh_token).to be nil
      expect(club.token_expires_at).to be nil
    end
    context 'without a refresh token (until October 2019)', vcr: { cassette_name: 'strava/refresh_access_token' } do
      before do
        club.update_attributes!(refresh_token: nil, token_expires_at: nil)
      end
      it 'refreshes access token using access token' do
        club.send(:strava_client)
        expect(club.refresh_token).to eq 'updated-refresh-token'
        expect(club.access_token).to eq 'updated-access-token'
        expect(club.token_expires_at).to_not be_nil
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
        expect(club.token_expires_at).to_not be_nil
        expect(club.token_type).to eq 'Bearer'
      end
    end
  end
  context 'brag!' do
    let!(:activity) { Fabricate(:club_activity, club: club) }
    it 'brags the last unbragged activity' do
      expect_any_instance_of(ClubActivity).to receive(:brag!).and_return(
        ts: '1503435956.000247',
        channel: {
          id: 'C1',
          name: 'channel'
        }
      )
      results = club.brag!
      expect(results[:ts]).to eq '1503435956.000247'
      expect(results[:channel]).to eq(id: 'C1', name: 'channel')
      expect(results[:activity]).to eq activity
    end
  end
  context 'sync_and_brag!', vcr: { cassette_name: 'strava/club_sync_new_strava_activities' } do
    it 'syncs and brags' do
      expect_any_instance_of(ClubActivity).to receive(:brag!)
      club.sync_and_brag!
    end
    it 'warns on error' do
      expect_any_instance_of(Logger).to receive(:warn).with(/unexpected error/)
      allow(club).to receive(:sync_new_strava_activities!).and_raise 'unexpected error'
      expect { club.sync_and_brag! }.to_not raise_error
    end
    context 'rate limit exceeded' do
      let(:rate_limit_exceeded_error) { Strava::Api::V3::ClientError.new(429, '{"message":"Rate Limit Exceeded","errors":[{"resource":"Application","field":"rate limit","code":"exceeded"}]}') }
      it 'raises an exception' do
        allow(club).to receive(:sync_new_strava_activities!).and_raise rate_limit_exceeded_error
        expect { club.sync_and_brag! }.to raise_error(Strava::Api::V3::ClientError, /Rate Limit Exceeded/)
      end
    end
  end
end
