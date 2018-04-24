module Api
  module Endpoints
    class SlackEndpoint < Grape::API
      format :json

      namespace :slack do
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
            club.connect_to_slack
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
            club.connect_to_slack
          else
            error!("Callback #{callback_id} is not supported.", 404)
          end
        end
      end
    end
  end
end
