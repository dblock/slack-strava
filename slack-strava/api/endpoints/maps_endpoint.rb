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
          Api::Middleware.logger.info "Getting map ID #{params[:id]}."
          activity = Activity.where('map._id' => BSON::ObjectId(params[:id])).first
          error!('Not Found', 404) unless activity
          Api::Middleware.logger.info "Found activity ID #{params[:id]} with URL #{activity.map.image_url}."
          content_type 'image/png'
          png = HTTParty.get(activity.map.image_url).body
          Api::Middleware.logger.info "Returning #{png.size} byte(s) of PNG for activity ID #{params[:id]}."
          body png
        end
      end
    end
  end
end
