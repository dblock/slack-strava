require 'spec_helper'

describe Api::Endpoints::StatusEndpoint do
  include Api::Test::EndpointTest

  before do
    allow_any_instance_of(Team).to receive(:ping!).and_return(ok: 1)
  end

  context 'status' do
    it 'returns a status' do
      status = client.status
      expect(status.teams_count).to eq 0
      expect(status.connected_users_count).to eq 0
    end

    context 'with a team' do
      let!(:team) { Fabricate(:team, active: false) }
      it 'returns a status with ping' do
        status = client.status
        expect(status.teams_count).to eq 1
        ping = status.ping
        expect(ping['ok']).to eq 1
      end
    end

    context 'with connected users' do
      let!(:team) { Fabricate(:team) }
      let!(:user) { Fabricate(:user, team: team) }
      let!(:connected_user) { Fabricate(:user, team: team, access_token: 'xyz') }
      before do
        allow(HTTParty).to receive_message_chain(:get, :body).and_return('PNG')
      end
      it 'returns a status with distance and users' do
        status = client.status
        expect(status.connected_users_count).to eq 1
      end
      context 'with activities' do
        let!(:activity1) { Fabricate(:user_activity, user: connected_user) }
        let!(:activity2) { Fabricate(:user_activity, user: connected_user) }
        let(:total_distance_in_miles) { activity1.distance_in_miles + activity2.distance_in_miles }
        it 'returns a status with distance and users' do
          status = client.status
          expect(status.total_distance_in_miles_s).to eq '28.01 miles'
          expect(status.connected_users_count).to eq 1
        end
      end
    end
  end
end
