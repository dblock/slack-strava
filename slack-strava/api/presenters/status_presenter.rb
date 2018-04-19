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
        team = Team.asc(:_id).first
        return unless team
        team.ping!
      end

      def teams_count
        Team.count
      end

      def active_teams_count
        Team.active.count
      end

      def connected_users_count
        User.connected_to_strava.count
      end

      def total_distance_in_miles
        Activity.sum(:distance) * 0.00062137
      end

      def total_distance_in_miles_s
        distance = total_distance_in_miles
        return unless distance && distance.positive?
        format('%g miles', format('%.2f', distance))
      end

      def base_url(opts)
        request = Grape::Request.new(opts[:env])
        request.base_url
      end
    end
  end
end
