module Api
  module Presenters
    module StatusPresenter
      include Roar::JSON::HAL
      include Roar::Hypermedia
      include Grape::Roar::Representer

      link :self do |opts|
        "#{base_url(opts)}/status"
      end

      property :teams_count
      property :active_teams_count
      property :total_distance_in_miles_s
      property :connected_users_count
      property :ping

      def ping
        status
      end

      def teams_count
        stats&.teams_count
      end

      def active_teams_count
        stats&.active_teams_count
      end

      def connected_users_count
        stats&.connected_users_count
      end

      def total_distance_in_miles
        stats&.total_distance_in_miles
      end

      def total_distance_in_miles_s
        stats&.total_distance_in_miles_s
      end

      def base_url(opts)
        request = Grape::Request.new(opts[:env])
        request.base_url
      end
    end
  end
end
