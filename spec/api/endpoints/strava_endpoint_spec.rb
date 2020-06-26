require 'spec_helper'

describe Api::Endpoints::StravaEndpoint do
  include Api::Test::EndpointTest

  context 'with a STRAVA_CLIENT_SECRET' do
    let(:token) { 'strava-verification-token' }
    let(:challenge) { 'unique-challenge' }
    before do
      ENV['STRAVA_CLIENT_SECRET'] = token
    end
    context 'webhook challenge' do
      it 'responds to a valid challenge' do
        get "/api/strava/event?hub.verify_token=#{StravaWebhook.instance.verify_token}&hub.challenge=#{challenge}&hub.mode=subscribe"
        expect(last_response.status).to eq 200
        response = JSON.parse(last_response.body)
        expect(response['hub.challenge']).to eq(challenge)
      end
      it 'returns access denied on an invalid challenge' do
        get "/api/strava/event?hub.verify_token=invalid&hub.challenge=#{challenge}&hub.mode=subscribe"
        expect(last_response.status).to eq 403
      end
    end
    context 'webhook event' do
      it 'responds to a valid event' do
        post '/api/strava/event',
             JSON.dump(
               aspect_type: 'update',
               event_time: 1_516_126_040,
               object_id: 1_360_128_428,
               object_type: 'activity',
               owner_id: 134_815,
               subscription_id: 120_475,
               updates: {
                 title: 'a run'
               }
             ),
             'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq 200
        response = JSON.parse(last_response.body)
        expect(response['ok']).to be true
      end
      context 'with a connected user' do
        let!(:user) { Fabricate(:user, access_token: 'token') }
        it 'syncs user' do
          expect_any_instance_of(User).to receive(:sync_and_brag!).once
          post '/api/strava/event',
               JSON.dump(
                 aspect_type: 'create',
                 event_time: 1_516_126_040,
                 object_id: 1_360_128_428,
                 object_type: 'activity',
                 owner_id: user.athlete.athlete_id.to_s,
                 subscription_id: 120_475,
                 updates: {
                   title: 'a run'
                 }
               ),
               'CONTENT_TYPE' => 'application/json'
          expect(last_response.status).to eq 200
          response = JSON.parse(last_response.body)
          expect(response['ok']).to be true
        end
        context 'with an existing activity' do
          let!(:activity) { Fabricate(:user_activity, user: user, map: nil) }
          it 'rebrags an existing activity' do
            expect_any_instance_of(User).to receive(:rebrag_activity!).once
            post '/api/strava/event',
                 JSON.dump(
                   aspect_type: 'update',
                   event_time: 1_516_126_040,
                   object_id: activity.strava_id,
                   object_type: 'activity',
                   owner_id: user.athlete.athlete_id.to_s,
                   subscription_id: 120_475,
                   updates: {
                     title: 'a run'
                   }
                 ),
                 'CONTENT_TYPE' => 'application/json'
            expect(last_response.status).to eq 200
            response = JSON.parse(last_response.body)
            expect(response['ok']).to be true
          end
        end
        it 'ignores delete' do
          expect_any_instance_of(User).to_not receive(:sync_and_brag!)
          expect_any_instance_of(User).to_not receive(:rebrag!)
          post '/api/strava/event',
               JSON.dump(
                 aspect_type: 'delete',
                 event_time: 1_516_126_040,
                 object_id: 1_360_128_428,
                 object_type: 'activity',
                 owner_id: user.athlete.athlete_id.to_s,
                 subscription_id: 120_475,
                 updates: {
                   title: 'a run'
                 }
               ),
               'CONTENT_TYPE' => 'application/json'
          expect(last_response.status).to eq 200
          response = JSON.parse(last_response.body)
          expect(response['ok']).to be true
        end
      end
    end
    after do
      ENV.delete('STRAVA_CLIENT_SECRET')
    end
  end
end
