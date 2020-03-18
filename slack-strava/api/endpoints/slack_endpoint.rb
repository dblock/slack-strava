require_relative 'requests'

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
          requires :channel_name, type: String
          requires :team_id, type: String
        end
        post '/command' do
          command = Requests::Command.new(params)
          command.slack_verification_token!

          case command.text
          when 'clubs'
            command.clubs!
          when 'connect'
            command.connect!
          when 'disconnect'
            command.disconnect!
          else
            { message: "I don't understand the `#{command.text}` command." }
          end
        end

        desc 'Respond to interactive slack buttons and actions.'
        params do
          requires :payload, type: JSON do
            requires :token, type: String
            requires :callback_id, type: String
            optional :type, type: String
            optional :trigger_id, type: String
            optional :response_url, type: String
            requires :channel, type: Hash do
              requires :id, type: String
              optional :name, type: String
            end
            requires :user, type: Hash do
              requires :id, type: String
              optional :name, type: String
            end
            requires :team, type: Hash do
              requires :id, type: String
              optional :domain, type: String
            end
            optional :actions, type: Array do
              requires :value, type: String
            end
            optional :message, type: Hash do
              requires :type, type: String
              requires :user, type: String
              requires :ts, type: String
              requires :text, type: String
            end
          end
        end
        post '/action' do
          command = Requests::Command.new(params)
          command.slack_verification_token!

          case command.action
          when 'club-connect-channel'
            command.club_connect_channel!
          when 'club-disconnect-channel'
            command.club_disconnect_channel!
          else
            error!("Callback #{command.action} is not supported.", 404)
          end
        end

        desc 'Handle Slack events.'
        params do
          requires :token, type: String
          requires :type, type: String
          optional :challenge, type: String
        end
        post '/event' do
          event = Requests::Event.new(params)
          event.slack_verification_token!

          case event.type
          when 'url_verification'
            event.challenge!
          when 'link_shared'
            event.unfurl!
          else
            error!("Event #{event.type} is not supported.", 404)
          end
        end
      end
    end
  end
end
