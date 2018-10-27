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
      let(:url) { "https://www.strava.com/oauth/authorize?client_id=&redirect_uri=https://slava.playplay.io/connect&response_type=code&scope=activity:read_all&state=#{user.id}" }
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
  context 'subscription expiration' do
    before do
      team.update_attributes!(created_at: 3.weeks.ago)
    end
    it 'prevents new connections' do
      expect(message: "#{SlackRubyBot.config.user} connect").to respond_with_slack_message(
        "Your trial subscription has expired. Subscribe your team for $9.99 a year at https://slava.playplay.io/subscribe?team_id=#{team.team_id} to continue receiving Strava activities in Slack. All proceeds donated to NYC TeamForKids charity."
      )
    end
  end
end
