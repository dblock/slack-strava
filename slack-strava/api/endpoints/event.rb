module Api
  module Endpoints
    class SlackEndpointCommands
      class Event
        attr_reader :token, :challenge, :type
        attr_reader :team_id, :api_app_id
        attr_reader :event

        def initialize(params)
          @token = params[:token]
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

        def slack_verification_token!
          return unless ENV.key?('SLACK_VERIFICATION_TOKEN')
          return if token == ENV['SLACK_VERIFICATION_TOKEN']

          throw :error, status: 401, message: 'Message token is not coming from Slack.'
        end

        def challenge!
          { challenge: challenge }
        end

        def logger
          Api::Middleware.logger
        end

        def team
          @team ||= Team.where(team_id: team_id).first
        end

        def user
          return unless team && event && event.user
          @user ||= team.users.where(user_id: event.user).first
        end

        def unfurl!
          return unless event && event.links && user

          event.links.each do |link|
            next unless link.domain == 'strava.com'
            m = link.url.match(/strava\.com\/activities\/(?<strava_id>\d+)\b/)
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
