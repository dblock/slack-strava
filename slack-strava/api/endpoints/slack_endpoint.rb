module Api
  module Endpoints
    class SlackEndpoint < Grape::API
      format :json

      namespace :slack do
        desc 'Respond to slash commands.'
        params do
          requires :command, type: String
          requires :text, type: String
          requires :token, type: String
          requires :user_id, type: String
          requires :channel_id, type: String
          requires :team_id, type: String
        end
        post '/command' do
          token = params['token']
          error!('Message token is not coming from Slack.', 401) if ENV.key?('SLACK_VERIFICATION_TOKEN') && token != ENV['SLACK_VERIFICATION_TOKEN']

          channel_id = params['channel_id']
          user_id = params['user_id']
          team_id = params['team_id']

          user = ::User.find_create_or_update_by_team_and_slack_id!(team_id, user_id)

          result = if channel_id[0] == 'D'
                     user.team.clubs_to_slack
                   else
                     user.athlete_clubs_to_slack(channel_id)
                   end

          result.merge(
            user: user_id, channel: channel_id
          )
        end

        desc 'Respond to interactive slack buttons and actions.'
        params do
          requires :payload, type: String
        end
        post '/action' do
          payload = JSON.parse(params[:payload])

          token = payload['token']
          error!('Message token is not coming from Slack.', 401) if ENV.key?('SLACK_VERIFICATION_TOKEN') && token != ENV['SLACK_VERIFICATION_TOKEN']

          callback_id = payload['callback_id']
          channel_id = payload['channel']['id']
          channel_name = payload['channel']['name']
          user_id = payload['user']['id']
          team_id = payload['team']['id']

          user = ::User.find_create_or_update_by_team_and_slack_id!(team_id, user_id)

          case callback_id
          when 'club-connect-channel' then
            raise 'User not connected to Strava.' unless user.connected_to_strava?
            strava_id = payload['actions'][0]['value']
            strava_club = Club.attrs_from_strava(user.strava_client.retrieve_a_club(strava_id))
            club = Club.create!(
              strava_club.merge(
                access_token: user.access_token,
                token_type: user.token_type,
                team: user.team,
                channel_id: channel_id,
                channel_name: channel_name
              )
            )
            Api::Middleware.logger.info "Connected #{club}, #{user}, #{user.team}."
            user.team.slack_client.chat_postMessage(
              club.to_slack.merge(
                as_user: true, channel: channel_id, text: "A club has been connected by #{user.slack_mention}."
              )
            )
            club.sync_last_strava_activity!
            user.athlete_clubs_to_slack(channel_id).merge(user: user_id, channel: channel_id)
          when 'club-disconnect-channel' then
            strava_id = payload['actions'][0]['value']
            club = Club.where(team: user.team, channel_id: channel_id).first
            raise "Club #{strava_id} not connected to #{channel_id}." unless club
            club.destroy
            Api::Middleware.logger.info "Disconnected #{club}, #{user}, #{user.team}."
            user.team.slack_client.chat_postMessage(
              club.to_slack.merge(
                as_user: true, channel: channel_id, text: "A club has been disconnected by #{user.slack_mention}."
              )
            )
            user.athlete_clubs_to_slack(channel_id).merge(user: user_id, channel: channel_id)
          else
            error!("Callback #{callback_id} is not supported.", 404)
          end
        end
      end
    end
  end
end
