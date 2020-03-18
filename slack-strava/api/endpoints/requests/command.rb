module Api
  module Endpoints
    module Requests
      class Command < Request
        attr_reader :action, :arg, :type
        attr_reader :channel_id, :channel_name
        attr_reader :user_id, :team_id
        attr_reader :text, :image_url, :response_url
        attr_reader :trigger_id, :submission, :message_ts

        def initialize(params)
          super(params)
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

        def clubs!
          logger.info "CLUBS: #{channel_id}, #{user}, #{user.team}."
          if channel_id[0] == 'D'
            user.team.clubs_to_slack.merge(user: user_id, channel: channel_id)
          elsif !user.team.bot_in_channel?(channel_id)
            {
              text: "Please invite #{user.team.bot_mention} to this channel before connecting a club.",
              user: user_id,
              channel: channel_id
            }
          else
            user.athlete_clubs_to_slack(channel_id).merge(user: user_id, channel: channel_id)
          end
        end

        def connect!
          logger.info "CONNECT: #{channel_id}, #{user}, #{user.team}."
          user.connect_to_strava.merge(user: user_id, channel: channel_id)
        end

        def disconnect!
          logger.info "DISCONNECT: #{channel_id}, #{user}, #{user.team}."
          user.disconnect_from_strava.merge(user: user_id, channel: channel_id)
        end

        def club_connect_channel!
          raise 'User not connected to Strava.' unless user.connected_to_strava?

          strava_id = arg
          strava_club = Club.attrs_from_strava(user.strava_client.club(strava_id))
          club = Club.create!(
            strava_club.merge(
              access_token: user.access_token,
              refresh_token: user.refresh_token,
              token_expires_at: user.token_expires_at,
              token_type: user.token_type,
              team: user.team,
              channel_id: channel_id,
              channel_name: channel_name
            )
          )
          logger.info "Connected #{club}, #{user}, #{user.team}."
          user.team.slack_client.chat_postMessage(
            club.to_slack.merge(
              as_user: true, channel: channel_id, text: "A club has been connected by #{user.slack_mention}."
            )
          )
          club.sync_last_strava_activity!
          user.athlete_clubs_to_slack(channel_id).merge(user: user_id, channel: channel_id)
        end

        def club_disconnect_channel!
          strava_id = arg
          club = Club.where(team: user.team, channel_id: channel_id).first
          raise "Club #{strava_id} not connected to #{channel_id}." unless club

          club.destroy
          logger.info "Disconnected #{club}, #{user}, #{user.team}."
          user.team.slack_client.chat_postMessage(
            club.to_slack.merge(
              as_user: true, channel: channel_id, text: "A club has been disconnected by #{user.slack_mention}."
            )
          )
          user.athlete_clubs_to_slack(channel_id).merge(user: user_id, channel: channel_id)
        end
      end
    end
  end
end
