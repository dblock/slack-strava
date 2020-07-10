module Api
  module Endpoints
    class MapsEndpoint < Grape::API
      content_type :png, 'image/png'

      namespace :maps do
        desc 'Proxy display a map.'
        params do
          requires :id, type: String
        end
        get ':id' do
          user_agent = headers['User-Agent'] || 'Unknown User-Agent'
          activity = UserActivity.where('map._id' => BSON::ObjectId(params[:id])).first
          unless activity
            Api::Middleware.logger.debug "Map #{params[:id]} for #{user_agent}, not found (404)."
            error!('Not Found', 404)
          end
          if activity.hidden?
            Api::Middleware.logger.debug "Map png for #{activity.user}, #{activity} for #{user_agent}, hidden (403)."
            error!('Access Denied', 403)
          end
          unless activity.map
            Api::Middleware.logger.debug "Map png for #{activity.user}, #{activity} for #{user_agent}, no map (404)."
            error!('Map Not Found', 404)
          end
          # will also re-fetch the map if needed
          activity.map.update_attributes!(png_retrieved_at: Time.now.utc)
          unless activity.map.png
            Api::Middleware.logger.debug "Map png for #{activity.user}, #{activity} for #{user_agent}, no data (404)."
            error!('Map Data Not Found', 404)
          end
          content_type 'image/png'
          png = activity.map.png.data
          Api::Middleware.logger.debug "Map png for #{activity.user}, #{activity} for #{user_agent}, #{png.size} byte(s)."
          body png
        end
      end
    end
  end
end
