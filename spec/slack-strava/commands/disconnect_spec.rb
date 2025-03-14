require 'spec_helper'

describe SlackStrava::Commands::Disconnect do
  let!(:team) { Fabricate(:team, created_at: 2.weeks.ago) }
  let(:app) { SlackStrava::Server.new(team: team) }
  let(:client) { app.send(:client) }
  let(:message_hook) { SlackRubyBot::Hooks::Message.new }

  context 'disconnect' do
    it 'requires a subscription' do
      expect(message: "#{SlackRubyBot.config.user} disconnect").to respond_with_slack_message(team.trial_message)
    end

    context 'subscribed team' do
      let(:team) { Fabricate(:team, subscribed: true) }

      context 'connected user' do
        let(:user) { Fabricate(:user, team: team, access_token: 'token', token_type: 'Bearer') }

        it 'disconnects a user' do
          expect(User).to receive(:find_create_or_update_by_slack_id!).and_return(user)
          expect(user).to receive(:dm!).with({ text: 'Your Strava account has been successfully disconnected.' })
          expect(user).to receive(:refresh_access_token!)
          expect(user.strava_client).to receive(:deauthorize).and_return(Hashie::Mash.new(access_token: 'token'))
          message_hook.call(client, Hashie::Mash.new(channel: 'channel', user: SlackRubyBot.config.user, text: "#{SlackRubyBot.config.user} disconnect"))
          user.reload
          expect(user.access_token).to be_nil
          expect(user.connected_to_strava_at).to be_nil
          expect(user.token_type).to be_nil
        end
      end

      context 'disconnected user' do
        let(:user) { Fabricate(:user, team: team) }

        it 'fails to disconnect a user' do
          expect(User).to receive(:find_create_or_update_by_slack_id!).and_return(user)
          expect(user).to receive(:dm!).with({ text: 'Your Strava account is not connected.' })
          message_hook.call(client, Hashie::Mash.new(channel: 'channel', user: SlackRubyBot.config.user, text: "#{SlackRubyBot.config.user} disconnect"))
        end
      end
    end
  end
end
