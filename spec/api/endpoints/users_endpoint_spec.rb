require 'spec_helper'

describe Api::Endpoints::UsersEndpoint do
  include Api::Test::EndpointTest

  context 'users' do
    let(:user) { Fabricate(:user) }
    it 'connects a user to their Strava account', vcr: { cassette_name: 'strava/retrieve_access' } do
      expect_any_instance_of(User).to receive(:dm!).with(
        text: 'Your Strava account has been successfully connected.'
      )

      expect_any_instance_of(User).to receive(:sync_last_strava_activity).and_return(nil)

      client.user(id: user.id)._put(code: 'code')

      user.reload

      expect(user.access_token).to eq 'token'
      expect(user.token_type).to eq 'Bearer'
      expect(user.athlete.athlete_id).to eq '12345'
    end
  end
end
