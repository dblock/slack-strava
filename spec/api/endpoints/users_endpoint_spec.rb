require 'spec_helper'

describe Api::Endpoints::UsersEndpoint do
  include Api::Test::EndpointTest

  context 'users' do
    let(:user) { Fabricate(:user) }
    it 'connects a user to their Strava account', vcr: { cassette_name: 'strava/retrieve_access' } do
      expect_any_instance_of(User).to receive(:dm!).with(
        text: "Your Strava account has been successfully connected.\nI won't post any private activities, DM me `set private on` to toggle that and `help` for other options."
      )

      expect_any_instance_of(User).to receive(:inform!).with(
        text: "New Strava account connected for #{user.slack_mention}."
      )

      client.user(id: user.id)._put(code: 'code')

      user.reload

      expect(user.access_token).to eq 'token'
      expect(user.connected_to_strava_at).to_not be nil
      expect(user.token_type).to eq 'Bearer'
      expect(user.athlete.athlete_id).to eq '12345'
    end
    context 'with prior activities' do
      before do
        allow_any_instance_of(Map).to receive(:update_png!)
        allow_any_instance_of(User).to receive(:inform!).and_return([{ ts: 'ts', channel: 'C1' }])
        2.times { Fabricate(:user_activity, user: user) }
        user.brag!
        user.disconnect_from_strava
      end
      it 'resets all activities', vcr: { cassette_name: 'strava/retrieve_access' } do
        expect {
          expect {
            expect_any_instance_of(User).to receive(:dm!).with(
              text: "Your Strava account has been successfully connected.\nI won't post any private activities, DM me `set private on` to toggle that and `help` for other options."
            )

            expect_any_instance_of(User).to receive(:inform!).with(
              text: "New Strava account connected for #{user.slack_mention}."
            )

            client.user(id: user.id)._put(code: 'code')

            user.reload

            expect(user.access_token).to eq 'token'
            expect(user.connected_to_strava_at).to_not be nil
            expect(user.token_type).to eq 'Bearer'
            expect(user.athlete.athlete_id).to eq '12345'
          }.to change(user.activities, :count).by(-2)
        }.to change(user, :activities_at)
      end
    end
  end
end
