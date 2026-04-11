module Api
  module Endpoints
    class MapsEndpoint < Grape::API
      content_type :png, 'image/png'

      # 1x1 transparent PNG pixel returned when a map is not available.
      PIXEL_PNG = Base64.decode64(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQI12NgAAIABQAABjE+ibYAAAAASUVORK5CYII='
      ).freeze

      namespace :maps do
        desc 'Proxy display a map.'
        params do
          requires :id, type: String
        end
        get ':id' do
          user_agent = headers['User-Agent'] || 'Unknown User-Agent'
          activity = UserActivity.where('map._id' => BSON::ObjectId(params[:id])).first
          if activity.nil?
            Api::Middleware.logger.info "Map #{params[:id]} for #{user_agent}, not found, returning pixel."
            content_type 'image/png'
            body MapsEndpoint::PIXEL_PNG
          elsif activity.hidden?
            Api::Middleware.logger.info "Map png for #{activity.user}, #{activity} for #{user_agent}, hidden, returning pixel."
            content_type 'image/png'
            body MapsEndpoint::PIXEL_PNG
          elsif !activity.map&.polyline?
            Api::Middleware.logger.info "Map png for #{activity.user}, #{activity} for #{user_agent}, no map, returning pixel."
            content_type 'image/png'
            body MapsEndpoint::PIXEL_PNG
          elsif activity.user.team.proxy_maps
            # will also re-fetch the map if needed
            activity.map.update_attributes!(png_retrieved_at: Time.now.utc)
            unless activity.map.png
              Api::Middleware.logger.info "Map png for #{activity.user}, #{activity} for #{user_agent}, no data, returning pixel."
              content_type 'image/png'
              next body MapsEndpoint::PIXEL_PNG
            end
            content_type 'image/png'
            png = activity.map.png.data
            Api::Middleware.logger.debug "Map png for #{activity.user}, #{activity} for #{user_agent}, #{png.size} byte(s)."
            body png
          elsif (png = activity.map.cached_png)
            content_type 'image/png'
            Api::Middleware.logger.debug "Map png cached for #{activity.user}, #{activity} for #{user_agent}, #{png.size} byte(s)."
            body png
          else
            redirect activity.map.image_url
          end
        end
      end
    end
  end
end
