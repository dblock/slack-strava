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

    it 'does not include count in the message' do
      expect(client.web_client).to receive(:chat_postMessage).with(
        text: 'There are no activities in this channel.',
        channel: 'DM',
        as_user: true
      )
      expect_any_instance_of(Team).to receive(:leaderboard).with(metric: 'count').and_call_original
      message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'DM', text: "#{SlackRubyBot.config.user} leaderboard count"))
    end

    context 'with a default team leaderboard' do
      before do
        team.update_attributes!(default_leaderboard: 'elapsed time since 2025')
      end

      it 'uses it without an expression' do
        Timecop.freeze do
          allow(client.web_client).to receive(:chat_postMessage)
          start_date = Time.new(2025, 1, 1)
          end_date = Time.now
          expect_any_instance_of(Team).to receive(:leaderboard).with(metric: 'elapsed time', start_date: start_date, end_date: end_date).and_call_original
          message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'DM', text: "#{SlackRubyBot.config.user} leaderboard"))
        end
      end

      it 'ignores it with an expression' do
        allow(client.web_client).to receive(:chat_postMessage)
        dt = Time.now - 2.days
        expect(Chronic).to receive(:parse).with('two days ago', context: :past, guess: false).and_return(dt)
        expect_any_instance_of(Team).to receive(:leaderboard).with(metric: 'distance', start_date: dt).and_call_original
        message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'DM', text: "#{SlackRubyBot.config.user} leaderboard two days ago"))
      end
    end

    it 'parses start date' do
      allow(client.web_client).to receive(:chat_postMessage)
      dt = Time.now - 2.days
      expect(Chronic).to receive(:parse).with('two days ago', context: :past, guess: false).and_return(dt)
      expect_any_instance_of(Team).to receive(:leaderboard).with(metric: 'distance', start_date: dt).and_call_original
      message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'DM', text: "#{SlackRubyBot.config.user} leaderboard two days ago"))
    end

    it 'parses year' do
      allow(client.web_client).to receive(:chat_postMessage)
      expect_any_instance_of(Team).to receive(:leaderboard).with(metric: 'distance', start_date: Time.new(2023, 1, 1), end_date: Time.new(2023, 1, 1).end_of_year).and_call_original
      message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'DM', text: "#{SlackRubyBot.config.user} leaderboard 2023"))
    end

    it 'parses a month' do
      allow(client.web_client).to receive(:chat_postMessage)
      start_date = Time.new(2023, 9, 1, 0, 0, 0)
      end_date = Time.new(2023, 10, 1, 0, 0, 0)
      expect_any_instance_of(Team).to receive(:leaderboard).with(metric: 'distance', start_date: start_date, end_date: end_date).and_call_original
      message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'DM', text: "#{SlackRubyBot.config.user} leaderboard September 2023"))
    end

    it 'parses an ISO date' do
      allow(client.web_client).to receive(:chat_postMessage)
      start_date = Time.new(2023, 3, 1, 0, 0, 0)
      end_date = Time.new(2023, 3, 2, 0, 0, 0)
      expect_any_instance_of(Team).to receive(:leaderboard).with(metric: 'moving time', start_date: start_date, end_date: end_date).and_call_original
      message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'DM', text: "#{SlackRubyBot.config.user} leaderboard moving time 2023-03-01"))
    end

    it 'parses since' do
      allow(client.web_client).to receive(:chat_postMessage)
      Timecop.freeze do
        start_date = Time.new(2023, 9, 1, 0, 0, 0)
        end_date = Time.now
        expect_any_instance_of(Team).to receive(:leaderboard).with(metric: 'distance', start_date: start_date, end_date: end_date).and_call_original
        message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'DM', text: "#{SlackRubyBot.config.user} leaderboard since September 2023"))
      end
    end

    it 'parses between' do
      allow(client.web_client).to receive(:chat_postMessage)
      start_date = Time.new(2023, 9, 1, 0, 0, 0)
      end_date = Time.new(2024, 9, 1, 0, 0, 0)
      expect_any_instance_of(Team).to receive(:leaderboard).with(metric: 'distance', start_date: start_date, end_date: end_date).and_call_original
      message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'DM', text: "#{SlackRubyBot.config.user} leaderboard between September 2023 and August 2024"))
    end
  end
end
