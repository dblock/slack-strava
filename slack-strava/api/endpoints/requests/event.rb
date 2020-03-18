module Api
  module Endpoints
    module Requests
      class Event < Request
        attr_reader :challenge, :type
        attr_reader :team_id, :api_app_id
        attr_reader :event

        def initialize(params)
          super(params)
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

            activity = user.sync_strava_activity!(m[:strava_id])
            next unless activity

            logger.info "UNFURL: #{link.url}, #{activity}"
            team.activated_user_slack_client.chat_unfurl(
              channel: event.channel,
              ts: event.message_ts,
              unfurls: {
                link.url => activity.to_slack_attachment
              }.to_json
            )
          end
        end
      end
    end
  end
end
