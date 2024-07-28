require 'spec_helper'

describe SlackStrava::Commands::Stats do
  let(:app) { SlackStrava::Server.new(team: team) }
  let(:client) { app.send(:client) }
  let(:message_hook) { SlackRubyBot::Hooks::Message.new }

  context 'subscribed team' do
    let!(:team) { Fabricate(:team, subscribed: true) }

    it 'stats' do
      expect(client.web_client).to receive(:chat_postMessage).with(
        team.stats(channel_id: 'channel').to_slack.merge(channel: 'channel', as_user: true)
      )
      message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'channel', text: "#{SlackRubyBot.config.user} stats"))
    end

    it 'includes channel' do
      expect(client.web_client).to receive(:chat_postMessage).with(
        team.stats(channel_id: 'channel').to_slack.merge(channel: 'channel', as_user: true)
      )
      expect_any_instance_of(Team).to receive(:stats).with(channel_id: 'channel').and_call_original
      message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'channel', text: "#{SlackRubyBot.config.user} stats"))
    end

    it 'does not include channel on a DM' do
      expect(client.web_client).to receive(:chat_postMessage).with(
        team.stats.to_slack.merge(channel: 'DM', as_user: true)
      )
      expect_any_instance_of(Team).to receive(:stats).with({}).and_call_original
      message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'DM', text: "#{SlackRubyBot.config.user} stats"))
    end
  end
end
