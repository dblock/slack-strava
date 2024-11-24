module Api
  module Endpoints
    module Requests
      class Event < Request
        attr_reader :challenge, :type, :team_id, :api_app_id, :event

        def initialize(params)
          super
          @challenge = params[:challenge]
          if params.key?(:event)
            @event = Hashie::Mash.new(params[:event])
            @type = @event.type
            @team_id = params[:team_id]
            @api_app_id = params[:api_app_id]
          else
            @type = params[:type]
          end
        end

        def challenge!
          { challenge: challenge }
        end

        def team
          @team ||= Team.where(team_id: team_id).first
        end

        def user
          return unless team && event && event.user

          @user ||= team.users.where(user_id: event.user).first
        end

        def unfurl!
          return unless event&.links && user

          event.links.each do |link|
            next unless link.domain == 'strava.com'

            m = link.url.match(%r{strava\.com/activities/(?<strava_id>\d+)\b})
            next unless m && m[:strava_id]

            unless user.connected_to_strava?
              logger.info "UNFURL: #{link.url}, #{user}, not connected to Strava"
              next
            end

            activity = user.sync_strava_activity!(m[:strava_id])

            if activity.nil?
              logger.info "UNFURL: #{link.url}, #{user}, missing activity"
              next
            end

            unfurls = { link.url => { blocks: activity.to_slack_blocks } }
            logger.info "UNFURL: #{link.url}, #{user}, #{activity}"
            logger.debug unfurls

            team.activated_user_slack_client.chat_unfurl(
              channel: event.channel,
              ts: event.message_ts,
              unfurls: unfurls.to_json
            )

            activity.update_attributes!(bragged_at: Time.now.utc)
          end
        end
      end
    end
  end
end
