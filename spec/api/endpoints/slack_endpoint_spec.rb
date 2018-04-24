require 'spec_helper'

describe Api::Endpoints::SlackEndpoint do
  include Api::Test::EndpointTest

  context 'with a SLACK_VERIFICATION_TOKEN' do
    let(:token) { 'slack-verification-token' }
    let(:team) { Fabricate(:team) }
    let(:user) { Fabricate(:user, team: team, access_token: 'token') }
    before do
      ENV['SLACK_VERIFICATION_TOKEN'] = token
    end
    context 'without a club' do
      let(:club) do
        Club.new(
          name: 'Orchard Street Runners',
          description: 'www.orchardstreetrunners.com',
          url: 'OrchardStreetRunners',
          city: 'New York',
          state: 'New York',
          country: 'United States',
          member_count: 146,
          logo: 'https://dgalywyr863hv.cloudfront.net/pictures/clubs/43749/1121181/4/medium.jpg'
        )
      end
      it 'connects club', vcr: { cassette_name: 'strava/retrieve_a_club' } do
        expect {
          expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with(
            club.to_slack.merge(
              as_user: true,
              channel: 'C12345',
              text: "A club has been connected by #{user.slack_mention}."
            )
          )
          expect_any_instance_of(Club).to receive(:sync_last_strava_activity!)
          post '/api/slack/action', payload: {
            'actions': [{ 'name' => 'strava_id', 'value' => '43749' }],
            'channel': { 'id' => 'C12345', 'name' => 'runs' },
            'user': { 'id' => user.user_id },
            'team': { 'id' => team.team_id },
            'token': token,
            'callback_id': 'club-connect-channel'
          }.to_json
          expect(last_response.status).to eq 201
          response = JSON.parse(last_response.body)
          expect(response['attachments'][0]['actions'][0]['text']).to eq 'Disconnect'
        }.to change(Club, :count).by(1)
      end
    end
    context 'with a club' do
      let!(:club) { Fabricate(:club, team: team) }
      it 'disconnects club' do
        expect {
          expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with(
            club.to_slack.merge(
              as_user: true,
              channel: club.channel_id,
              text: "A club has been disconnected by #{user.slack_mention}."
            )
          )
          post '/api/slack/action', payload: {
            'actions': [{ 'name' => 'strava_id', 'value' => club.strava_id }],
            'channel': { 'id' => club.channel_id, 'name' => 'runs' },
            'user': { 'id' => user.user_id },
            'team': { 'id' => team.team_id },
            'token': token,
            'callback_id': 'club-disconnect-channel'
          }.to_json
          expect(last_response.status).to eq 201
          response = JSON.parse(last_response.body)
          expect(response['attachments'][0]['actions'][0]['text']).to eq 'Connect'
        }.to change(Club, :count).by(-1)
      end
    end
    it 'returns an error with a non-matching verification token' do
      post '/api/slack/action', payload: {
        'token': 'invalid-token'
      }.to_json
      expect(last_response.status).to eq 401
      expect(JSON.parse(last_response.body)).to eq('error' => 'Message token is not coming from Slack.')
    end
    it 'returns invalid callback id' do
      post '/api/slack/action', payload: {
        'channel': { 'id' => 'C1', 'name' => 'runs' },
        'user': { 'id' => user.user_id },
        'team': { 'id' => team.team_id },
        'callback_id': 'invalid-callback',
        'token': token
      }.to_json
      expect(last_response.status).to eq 404
      response = JSON.parse(last_response.body)
      expect(response).to eq('error' => 'Callback invalid-callback is not supported.')
    end
    after do
      ENV.delete('SLACK_VERIFICATION_TOKEN')
    end
  end
end
