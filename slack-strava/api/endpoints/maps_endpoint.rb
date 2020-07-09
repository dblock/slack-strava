module Api
  module Endpoints
    class MapsEndpoint < Grape::API
      content_type :png, 'image/png'
      content_type :jpg, 'image/jpeg'

      namespace :maps do
        desc 'Proxy display a map.'
        params do
          requires :id, type: String
        end
        get ':id' do
          user_agent = headers['User-Agent'] || 'Unknown User-Agent'
          Api::Middleware.logger.debug "Getting map ID #{params[:id]} for #{user_agent}."
          activity = Activity.where('map._id' => BSON::ObjectId(params[:id])).first
          unless activity
            Api::Middleware.logger.debug "Activity for map ID #{params[:id]} for #{user_agent} has not been found, 404."
            error!('Not Found', 404)
          end
          if activity.hidden?
            Api::Middleware.logger.debug "Activity #{activity.strava_id} for map ID #{params[:id]} for #{user_agent} is hidden, 403."
            error!('Access Denied', 403)
          end
          unless activity.map
            Api::Middleware.logger.debug "Activity #{activity.strava_id} has no map ID #{params[:id]} for #{user_agent}, 404."
            error!('Map Not Found', 404)
          end
          # will also re-fetch the map if needed
          activity.map.update_attributes!(png_retrieved_at: Time.now.utc)
          unless activity.map.png
            Api::Middleware.logger.debug "Activity #{activity.strava_id} has no map ID #{params[:id]} data for #{user_agent}, 404."
            error!('Map Data Not Found', 404)
          end
          Api::Middleware.logger.debug "Found activity #{activity.strava_id} for map ID #{params[:id]} with URL #{activity.map.proxy_image_url(activity.user.team.maps_format)}."
          case params[:format]
          when 'jpg'
            content_type 'image/jpeg'
            stream = MiniMagick::Image.read(StringIO.new(activity.map.png.data), 'png')
            stream.format 'jpg'
            jpg = stream.to_blob
            Api::Middleware.logger.debug "Returning #{jpg.size} byte(s) of JPG for activity #{activity.strava_id} map ID #{params[:id]}."
            body jpg
          when 'png'
            content_type 'image/png'
            png = activity.map.png.data
            Api::Middleware.logger.debug "Returning #{png.size} byte(s) of PNG for activity #{activity.strava_id} map ID #{params[:id]}."
            body png
          else
            error!('Unsupported Image Format', 400)
          end
        end
      end
    end
  end
end
