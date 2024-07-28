require 'spec_helper'

describe Api::Endpoints::MapsEndpoint do
  include Api::Test::EndpointTest

  context 'maps' do
    context 'without an activity' do
      it '404s' do
        get '/api/maps/5abd07019b0b58f119c1bbaa.png'
        expect(last_response.status).to eq 404
        expect(JSON.parse(last_response.body)).to eq('error' => 'Not Found')
      end
    end

    context 'with proxy maps on' do
      let(:team) { Fabricate(:team, proxy_maps: true) }
      let(:user) { Fabricate(:user, team: team) }

      context 'with an activity' do
        let(:activity) { Fabricate(:user_activity, user: user) }

        it 'returns map and updates map timestamp', vcr: { cassette_name: 'strava/map' } do
          get "/api/maps/#{activity.map.id}.png"
          expect(last_response.status).to eq 200
          expect(last_response.headers['Content-Type']).to eq 'image/png'
          expect(activity.reload.map.png_retrieved_at).not_to be_nil
        end

        it 'handles if-none-match', vcr: { cassette_name: 'strava/map' } do
          get "/api/maps/#{activity.map.id}.png"
          expect(last_response.status).to eq 200
          expect(last_response.headers['ETag']).not_to be_nil
          get "/api/maps/#{activity.map.id}.png", {}, 'HTTP_IF_NONE_MATCH' => last_response.headers['ETag']
          expect(last_response.status).to eq 304
        end

        it 'returns no map data' do
          allow_any_instance_of(Map).to receive(:update_png!)
          get "/api/maps/#{activity.map.id}.png"
          expect(last_response.status).to eq 404
        end

        it 'refetches map if needed', vcr: { cassette_name: 'strava/map', allow_playback_repeats: true } do
          expect(activity.map.png).not_to be_nil
          activity.map.delete_png!
          expect(activity.reload.map.png).to be_nil
          get "/api/maps/#{activity.map.id}.png"
          expect(last_response.status).to eq 200
          expect(last_response.headers['Content-Type']).to eq 'image/png'
          expect(activity.reload.map.png).not_to be_nil
        end

        context 'with map', vcr: { cassette_name: 'strava/map' } do
          it 'updates map timestamp' do
            get "/api/maps/#{activity.map.id}.png"
            expect(last_response.status).to eq 200
            expect(activity.reload.map.png_retrieved_at).not_to be_nil
          end

          it 'returns content-type' do
            get "/api/maps/#{activity.map.id}.png"
            expect(last_response.status).to eq 200
            expect(last_response.headers['Content-Type']).to eq 'image/png'
          end

          it 'returns content-length' do
            get "/api/maps/#{activity.map.id}.png"
            expect(last_response.status).to eq 200
            expect(last_response.headers['Content-Length']).to eq last_response.body.size.to_s
          end

          it 'handles if-none-match' do
            get "/api/maps/#{activity.map.id}.png"
            expect(last_response.status).to eq 200
            expect(last_response.headers['ETag']).not_to be_nil
            get "/api/maps/#{activity.map.id}.png", {}, 'HTTP_IF_NONE_MATCH' => last_response.headers['ETag']
            expect(last_response.status).to eq 304
          end
        end
      end
    end

    context 'with defaults' do
      let(:team) { Fabricate(:team) }
      let(:user) { Fabricate(:user, team: team) }
      let(:activity) { Fabricate(:user_activity, user: user) }

      before do
        team.update_attributes!(proxy_maps: false)
      end

      it 'redirects to Google map' do
        get "/api/maps/#{activity.map.id}.png"
        expect(last_response.status).to eq 302
        expect(last_response.headers['Location']).to start_with 'https://maps.googleapis.com'
      end
    end

    context 'with a private activity', vcr: { cassette_name: 'strava/map' } do
      let(:user) { Fabricate(:user, private_activities: false) }
      let(:activity) { Fabricate(:user_activity, private: true, user: user) }

      it 'does not return map' do
        get "/api/maps/#{activity.map.id}.png"
        expect(last_response.status).to eq 403
      end
    end
  end
end
