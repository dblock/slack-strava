require 'spec_helper'

describe SlackStrava::Commands::Leaderboard do
  let(:app) { SlackStrava::Server.new(team: team) }
  let(:client) { app.send(:client) }
  let(:message_hook) { SlackRubyBot::Hooks::Message.new }
  context 'subscribed team' do
    let!(:team) { Fabricate(:team, subscribed: true) }
    it 'leaderboard' do
      expect(client.web_client).to receive(:chat_postMessage).with(
        text: team.leaderboard(metric: 'Distance').to_s,
        channel: 'channel',
        as_user: true
      )
      message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'channel', text: "#{SlackRubyBot.config.user} leaderboard"))
    end
    it 'heart rate' do
      expect(client.web_client).to receive(:chat_postMessage).with(
        text: team.leaderboard(metric: 'Heart Rate').to_s,
        channel: 'channel',
        as_user: true
      )
      message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'channel', text: "#{SlackRubyBot.config.user} leaderboard Heart Rate"))
    end
    it 'includes channel' do
      expect(client.web_client).to receive(:chat_postMessage).with(
        text: team.leaderboard(metric: 'Distance', channel_id: 'channel').to_s,
        channel: 'channel',
        as_user: true
      )
      expect_any_instance_of(Team).to receive(:leaderboard).with(channel_id: 'channel', metric: 'distance').and_call_original
      message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'channel', text: "#{SlackRubyBot.config.user} leaderboard"))
    end
    it 'does not include channel on a DM' do
      expect(client.web_client).to receive(:chat_postMessage).with(
        text: team.leaderboard(metric: 'Distance').to_s,
        channel: 'DM',
        as_user: true
      )
      expect_any_instance_of(Team).to receive(:leaderboard).with(metric: 'distance').and_call_original
      message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'DM', text: "#{SlackRubyBot.config.user} leaderboard"))
    end
  end
end
