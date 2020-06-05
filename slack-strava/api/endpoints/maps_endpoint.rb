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
          Api::Middleware.logger.debug "Getting map ID #{params[:id]}."
          activity = Activity.where('map._id' => BSON::ObjectId(params[:id])).first
          error!('Not Found', 404) unless activity
          error!('Access Denied', 403) if activity.hidden?
          error!('Map Not Found', 404) unless activity.map
          # will also re-fetch the map if needed
          activity.map.update_attributes!(png_retrieved_at: Time.now.utc)
          error!('Map Data Not Found', 404) unless activity.map.png
          Api::Middleware.logger.debug "Found activity ID #{params[:id]} with URL #{activity.map.proxy_image_url}."
          content_type 'image/png'
          png = activity.map.png.data
          Api::Middleware.logger.debug "Returning #{png.size} byte(s) of PNG for activity ID #{params[:id]}."
          body png
        end
      end
    end
  end
end
