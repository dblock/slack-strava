module Api
  module Endpoints
    class StravaEndpoint < Grape::API
      format :json

      namespace :strava do
        namespace :event do
          desc 'Respond to a webhook challenge.'
          params do
            requires 'hub.verify_token', type: String
            requires 'hub.challenge', type: String
            requires 'hub.mode', type: String
          end
          get do
            Api::Middleware.logger.info "Responding to a Strava webhook #{params['hub.mode']} challenge (#{params['hub.verify_token']})."
            error!('Invalid token', 403) unless params['hub.verify_token'] == StravaWebhook.instance.verify_token
            { 'hub.challenge' => params['hub.challenge'] }
          end

          desc 'Respond to a webhook event.'
          params do
            requires 'object_type', type: String
            requires 'object_id', type: String
            requires 'aspect_type', type: String
            requires 'updates', type: Hash
            requires 'owner_id', type: String
            requires 'subscription_id', type: String
            requires 'event_time', type: Time, coerce_with: ->(v) { Time.at(v) }
          end
          post do
            User.connected_to_strava.where('athlete.athlete_id' => params['owner_id']).each do |user|
              case params['aspect_type']
              when 'create'
                Api::Middleware.logger.info "Syncing team #{user.team}, user #{user}, #{user.athlete}, #{params['object_type']}=#{params['object_id']}."
                user.sync_and_brag!
              when 'update'
                Api::Middleware.logger.info "Updating team #{user.team}, user #{user}, #{user.athlete}, #{params['object_type']}=#{params['object_id']}, #{params['updates']}."
                user.rebrag!
              else
                Api::Middleware.logger.info "Skipping team #{user.team}, user #{user}, #{user.athlete}, aspect_type=#{params['aspect_type']}, #{params['object_type']}=#{params['object_id']}."
              end
            end
            status 200
            { ok: true }
          end
        end
      end
    end
  end
end
