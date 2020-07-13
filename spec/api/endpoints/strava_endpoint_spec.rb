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
      let(:event_data) do
        {
          aspect_type: 'update',
          event_time: 1_516_126_040,
          object_id: 1_360_128_428,
          object_type: 'activity',
          owner_id: 134_815,
          subscription_id: 120_475,
          updates: {}
        }
      end
      it 'responds to a valid event' do
        post '/api/strava/event',
             JSON.dump(event_data),
             'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to eq 200
        response = JSON.parse(last_response.body)
        expect(response['ok']).to be true
      end
      context 'with a connected user' do
        let!(:user) { Fabricate(:user, access_token: 'token') }
        it 'syncs user' do
          expect_any_instance_of(Logger).to receive(:info).with(/Syncing activity/).and_call_original
          expect_any_instance_of(User).to receive(:sync_and_brag!).once
          post '/api/strava/event',
               JSON.dump(
                 event_data.merge(
                   aspect_type: 'create',
                   owner_id: user.athlete.athlete_id.to_s
                 )
               ),
               'CONTENT_TYPE' => 'application/json'
          expect(last_response.status).to eq 200
          response = JSON.parse(last_response.body)
          expect(response['ok']).to be true
        end
        context 'with an expired subscription' do
          let(:team) { Fabricate(:team, created_at: 3.weeks.ago) }
          let!(:user) { Fabricate(:user, access_token: 'token', team: team) }
          it 'does not sync user' do
            expect_any_instance_of(Logger).to receive(:info).with(/expired/).and_call_original
            expect_any_instance_of(User).to_not receive(:sync_and_brag!).once
            post '/api/strava/event',
                 JSON.dump(
                   event_data.merge(
                     aspect_type: 'create',
                     owner_id: user.athlete.athlete_id.to_s
                   )
                 ),
                 'CONTENT_TYPE' => 'application/json'
            expect(last_response.status).to eq 200
            response = JSON.parse(last_response.body)
            expect(response['ok']).to be true
          end
        end
        context 'with an existing activity' do
          let!(:activity) { Fabricate(:user_activity, user: user, map: nil) }
          it 'rebrags the existing activity' do
            expect_any_instance_of(Logger).to receive(:info).with(/Updating activity/).and_call_original
            expect_any_instance_of(User).to receive(:rebrag_activity!) do |u, a|
              expect(u).to eq user
              expect(a).to eq activity
            end
            post '/api/strava/event',
                 JSON.dump(
                   event_data.merge(
                     aspect_type: 'update',
                     object_id: activity.strava_id,
                     owner_id: user.athlete.athlete_id.to_s
                   )
                 ),
                 'CONTENT_TYPE' => 'application/json'
            expect(last_response.status).to eq 200
            response = JSON.parse(last_response.body)
            expect(response['ok']).to be true
          end
          it 'ignores non-existent activities' do
            expect_any_instance_of(Logger).to receive(:info).with(/Ignoring activity/).and_call_original
            expect_any_instance_of(User).to_not receive(:rebrag_activity!)
            post '/api/strava/event',
                 JSON.dump(
                   event_data.merge(
                     aspect_type: 'update',
                     object_id: 'other',
                     owner_id: user.athlete.athlete_id.to_s
                   )
                 ),
                 'CONTENT_TYPE' => 'application/json'
            expect(last_response.status).to eq 200
            response = JSON.parse(last_response.body)
            expect(response['ok']).to be true
          end
          it 'skips other object types' do
            expect_any_instance_of(Logger).to receive(:warn).with(/Ignoring object type 'other'/).and_call_original
            expect_any_instance_of(User).to_not receive(:rebrag_activity!)
            post '/api/strava/event',
                 JSON.dump(
                   event_data.merge(
                     aspect_type: 'update',
                     object_type: 'other',
                     object_id: activity.strava_id,
                     owner_id: user.athlete.athlete_id.to_s
                   )
                 ),
                 'CONTENT_TYPE' => 'application/json'
            expect(last_response.status).to eq 200
            response = JSON.parse(last_response.body)
            expect(response['ok']).to be true
          end
          it 'ignores delete' do
            expect_any_instance_of(Logger).to receive(:info).with(/Ignoring aspect type 'delete'/).and_call_original
            expect_any_instance_of(User).to_not receive(:sync_and_brag!)
            expect_any_instance_of(User).to_not receive(:rebrag!)
            post '/api/strava/event',
                 JSON.dump(
                   event_data.merge(
                     aspect_type: 'delete',
                     object_id: activity.strava_id,
                     owner_id: user.athlete.athlete_id.to_s
                   )
                 ),
                 'CONTENT_TYPE' => 'application/json'
            expect(last_response.status).to eq 200
            response = JSON.parse(last_response.body)
            expect(response['ok']).to be true
          end
        end
      end
    end
    after do
      ENV.delete('STRAVA_CLIENT_SECRET')
    end
  end
end
