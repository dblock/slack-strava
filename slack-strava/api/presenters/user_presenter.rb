module Api
  module Presenters
    module UserPresenter
      include Roar::JSON::HAL
      include Roar::Hypermedia
      include Grape::Roar::Representer

      property :id, type: String, desc: 'User ID.'
      property :user_id, type: String, desc: 'User id.'
      property :user_name, type: String, desc: 'User name.'
      property :created_at, type: DateTime, desc: 'Date/time when the user was created.'
      property :updated_at, type: DateTime, desc: 'Date/time when the user was accepted, declined or canceled.'

      link :team do |opts|
        request = Grape::Request.new(opts[:env])
        "#{request.base_url}/api/teams/#{team_id}"
      end

      link :self do |opts|
        request = Grape::Request.new(opts[:env])
        "#{request.base_url}/api/users/#{id}"
      end
    end
  end
end
