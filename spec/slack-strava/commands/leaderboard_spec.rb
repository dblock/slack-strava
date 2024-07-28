require 'spec_helper'

describe SlackStrava::Commands::Leaderboard do
  let(:app) { SlackStrava::Server.new(team: team) }
  let(:client) { app.send(:client) }
  let(:message_hook) { SlackRubyBot::Hooks::Message.new }

  context 'subscribed team' do
    let!(:team) { Fabricate(:team, subscribed: true) }

    it 'leaderboard' do
      expect(client.web_client).to receive(:chat_postMessage).with(
        text: 'There are no activities with distance in this channel.',
        channel: 'channel',
        as_user: true
      )
      message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'channel', text: "#{SlackRubyBot.config.user} leaderboard"))
    end

    it 'elapsed time' do
      expect(client.web_client).to receive(:chat_postMessage).with(
        text: 'There are no activities with elapsed time in this channel.',
        channel: 'channel',
        as_user: true
      )
      message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'channel', text: "#{SlackRubyBot.config.user} leaderboard elapsed time"))
    end

    it 'includes channel' do
      expect(client.web_client).to receive(:chat_postMessage).with(
        text: 'There are no activities with distance in this channel.',
        channel: 'channel',
        as_user: true
      )
      expect_any_instance_of(Team).to receive(:leaderboard).with(channel_id: 'channel', metric: 'distance').and_call_original
      message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'channel', text: "#{SlackRubyBot.config.user} leaderboard"))
    end

    it 'does not include channel on a DM' do
      expect(client.web_client).to receive(:chat_postMessage).with(
        text: 'There are no activities with distance in this channel.',
        channel: 'DM',
        as_user: true
      )
      expect_any_instance_of(Team).to receive(:leaderboard).with(metric: 'distance').and_call_original
      message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'DM', text: "#{SlackRubyBot.config.user} leaderboard"))
    end
  end
end
