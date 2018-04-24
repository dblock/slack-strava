require 'spec_helper'

describe SlackStrava::Commands::Clubs do
  let!(:team) { Fabricate(:team) }
  let(:app) { SlackStrava::Server.new(team: team) }
  let(:client) { app.send(:client) }
  let(:message_hook) { SlackRubyBot::Hooks::Message.new }
  context 'clubs' do
    it 'requires a subscription' do
      expect(message: "#{SlackRubyBot.config.user} clubs").to respond_with_slack_message(team.subscribe_text)
    end
    context 'subscribed team' do
      let(:team) { Fabricate(:team, subscribed: true) }
      context 'disconnected user' do
        let(:user) { Fabricate(:user, team: team) }
        before do
          allow(User).to receive(:find_create_or_update_by_slack_id!).and_return(user)
        end
        let!(:club_in_another_channel) { Fabricate(:club, team: team, channel_id: 'another') }
        let!(:club) { Fabricate(:club, team: team, channel_id: 'channel') }
        it 'lists clubs connected to this channel' do
          expect(client.web_client).to receive(:chat_postEphemeral).with(
            club.connect_to_slack.merge(
              text: '', user: user.user_name, as_user: true, channel: 'channel'
            )
          )
          message_hook.call(client, Hashie::Mash.new(channel: 'channel', user: user.user_name, text: "#{SlackRubyBot.config.user} clubs"))
        end
      end
      context 'connected user' do
        let(:user) { Fabricate(:user, team: team, access_token: 'token') }
        let(:nyrr_club) do
          Club.new(
            strava_id: '108605',
            name: 'New York Road Runners',
            url: 'nyrr',
            city: 'New York',
            state: 'New York',
            country: 'United States',
            member_count: 9131,
            logo: 'https://dgalywyr863hv.cloudfront.net/pictures/clubs/108605/8433029/1/medium.jpg'
          )
        end
        before do
          allow(User).to receive(:find_create_or_update_by_slack_id!).and_return(user)
        end
        it 'lists clubs a user is a member of', vcr: { cassette_name: 'strava/list_athlete_clubs' } do
          expect(client.web_client).to receive(:chat_postEphemeral).with(
            nyrr_club.connect_to_slack.merge(
              text: '', user: user.user_name, as_user: true, channel: 'channel'
            )
          )
          expect(client.web_client).to receive(:chat_postEphemeral).exactly(4).times
          message_hook.call(client, Hashie::Mash.new(channel: 'channel', user: user.user_name, text: "#{SlackRubyBot.config.user} clubs"))
        end
        context 'with another connected club in the channel' do
          let!(:club_in_another_channel) { Fabricate(:club, team: team, channel_id: 'another') }
          let!(:club) { Fabricate(:club, team: team, channel_id: 'channel') }
          it 'lists both clubs a user is a member of and the connected club', vcr: { cassette_name: 'strava/list_athlete_clubs' } do
            expect(client.web_client).to receive(:chat_postEphemeral).with(
              club.connect_to_slack.merge(
                text: '', user: user.user_name, as_user: true, channel: 'channel'
              )
            )
            expect(client.web_client).to receive(:chat_postEphemeral).with(
              nyrr_club.connect_to_slack.merge(
                text: '', user: user.user_name, as_user: true, channel: 'channel'
              )
            )
            expect(client.web_client).to receive(:chat_postEphemeral).exactly(4).times
            message_hook.call(client, Hashie::Mash.new(channel: 'channel', user: user.user_name, text: "#{SlackRubyBot.config.user} clubs"))
          end
        end
        context 'DMs' do
          it 'says no clubs are connected in a DM' do
            expect(client).to receive(:say).with(
              text: 'No clubs currently connected.', as_user: true, channel: 'DM'
            )
            message_hook.call(client, Hashie::Mash.new(channel: 'DM', user: user.user_name, text: 'clubs'))
          end
          context 'with a connected club' do
            let!(:club) { Fabricate(:club, team: team) }
            it 'lists connected clubs in a DM' do
              expect(client.web_client).to receive(:chat_postMessage).with(
                club.to_slack.merge(
                  as_user: true,
                  channel: 'DM'
                ).tap { |msg|
                  msg[:attachments][0][:text] += "\nConnected to <##{club.channel_id}>."
                }
              )
              message_hook.call(client, Hashie::Mash.new(channel: 'DM', user: user.user_name, text: 'clubs'))
            end
          end
        end
      end
    end
  end
end
