require 'spec_helper'

describe SlackStrava::Commands::Connect do
  let!(:team) { Fabricate(:team) }
  let(:app) { SlackStrava::Server.new(team: team) }
  let(:client) { app.send(:client) }
  let(:message_hook) { SlackRubyBot::Hooks::Message.new }
  context 'connect' do
    it 'requires a subscription' do
      expect(message: "#{SlackRubyBot.config.user} connect").to respond_with_slack_message(team.subscribe_text)
    end
    context 'subscribed team' do
      let(:team) { Fabricate(:team, subscribed: true) }
      let(:user) { Fabricate(:user, team: team) }
      let(:url) { "https://www.strava.com/oauth/authorize?client_id=&redirect_uri=https://slava.playplay.io/connect&response_type=code&scope=view_private&state=#{user.id}" }
      it 'connects a user', vcr: { cassette_name: 'slack/user_info' } do
        expect(User).to receive(:find_create_or_update_by_slack_id!).and_return(user)
        expect(user).to receive(:dm!).with(
          text: 'Please connect your Strava account.',
          attachments: [{
            fallback: "Please connect your Strava account at #{url}.",
            actions: [{
              type: 'button',
              text: 'Click Here',
              url: url
            }]
          }]
        )
        message_hook.call(client, Hashie::Mash.new(channel: 'channel', user: SlackRubyBot.config.user, text: "#{SlackRubyBot.config.user} connect"))
      end
    end
  end
end
