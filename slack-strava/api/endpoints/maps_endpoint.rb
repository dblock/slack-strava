module Api
  module Endpoints
    class MapsEndpoint < Grape::API
      content_type :jpg, 'image/jpg'

      namespace :maps do
        desc 'Proxy display a map.'
        params do
          requires :id, type: String
        end
        get ':id' do
          activity = Activity.where('map._id' => BSON::ObjectId(params[:id])).first
          error('Not Found', 404) unless activity
          content_type 'image/jpg'
          jpg = HTTParty.get(activity.map.image_url).body
          body jpg
        end
      end
    end
  end
end
