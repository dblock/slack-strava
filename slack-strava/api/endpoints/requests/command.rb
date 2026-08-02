module Api
  module Endpoints
    module Requests
      class Command < Request
        attr_reader :action, :arg, :type, :channel_id, :channel_name, :user_id, :team_id, :text, :image_url, :response_url, :trigger_id, :submission, :message_ts

        def initialize(params)
          super
          if params.key?(:payload)
            payload = params[:payload]
            @action = payload[:callback_id]
            @channel_id = payload[:channel][:id]
            @channel_name = payload[:channel][:name]
            @user_id = payload[:user][:id]
            @team_id = payload[:team][:id]
            @type = payload[:type]
            @message_ts = payload[:message_ts]
            if params[:payload].key?(:actions)
              @arg = payload[:actions][0][:value]
              @text = [action, arg].join(' ')
            elsif params[:payload].key?(:message)
              payload_message = payload[:message]
              @text = payload_message[:text]
              @message_ts ||= payload_message[:ts]
              if payload_message.key?(:attachments)
                payload_message[:attachments].each do |attachment|
                  @text = [@text, attachment[:image_url]].compact.join("\n")
                end
              end
            end
            @token = payload[:token]
            @response_url = payload[:response_url]
            @trigger_id = payload[:trigger_id]
            @submission = payload[:submission]
          else
            @text = params[:text]
            @action, @arg = text.split(/\s/, 2)
            @channel_id = params[:channel_id]
            @channel_name = params[:channel_name]
            @user_id = params[:user_id]
            @team_id = params[:team_id]
            @token = params[:token]
          end
        end

        def user
          @user ||= ::User.find_create_or_update_by_team_and_slack_id!(
            team_id,
            user_id
          )
        end

        def stats!
          logger.info "STATS: #{channel_id}, #{user}, #{user.team}."
          options = {}
          options.merge!(channel_id: channel_id) unless channel_id[0] == 'D'
          user.team.stats(options).to_slack.merge(
            user: user_id,
            channel: channel_id
          )
        end

        def leaderboard!
          logger.info "LEADERBOARD: #{channel_id}, #{user}, #{user.team}."
          options = {}
          options.merge!(channel_id: channel_id) unless channel_id[0] == 'D'
          {
            text: user.team.leaderboard(options.merge(metric: arg || 'Distance')).to_s,
            user: user_id,
            channel: channel_id
          }
        end

        def connect!
          logger.info "CONNECT: #{channel_id}, #{user}, #{user.team}."
          user.connect_to_strava.merge(user: user_id, channel: channel_id)
        end

        def disconnect!
          logger.info "DISCONNECT: #{channel_id}, #{user}, #{user.team}."
          user.disconnect_from_strava.merge(user: user_id, channel: channel_id)
        end
      end
    end
  end
end
