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

    context 'with date expressions' do
      it 'stats 2018' do
        expect(client.web_client).to receive(:chat_postMessage)
        expect_any_instance_of(Team).to receive(:stats).with(
          hash_including(channel_id: 'channel', start_date: Time.new(2018, 1, 1))
        ).and_call_original
        message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'channel', text: "#{SlackRubyBot.config.user} stats 2018"))
      end

      it 'parses weekly' do
        allow(client.web_client).to receive(:chat_postMessage)
        Timecop.freeze do
          parsed = Chronic.parse('this week', context: :past, guess: false)
          expect_any_instance_of(Team).to receive(:stats).with(start_date: parsed.first, end_date: parsed.last, channel_id: 'channel').and_call_original
          message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'channel', text: "#{SlackRubyBot.config.user} stats weekly"))
        end
      end

      it 'parses monthly' do
        allow(client.web_client).to receive(:chat_postMessage)
        Timecop.freeze do
          parsed = Chronic.parse('this month', context: :past, guess: false)
          expect_any_instance_of(Team).to receive(:stats).with(start_date: parsed.first, end_date: parsed.last, channel_id: 'channel').and_call_original
          message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'channel', text: "#{SlackRubyBot.config.user} stats monthly"))
        end
      end

      it 'parses yearly' do
        allow(client.web_client).to receive(:chat_postMessage)
        Timecop.freeze do
          parsed = Chronic.parse('this year', context: :past, guess: false)
          expect_any_instance_of(Team).to receive(:stats).with(start_date: parsed.first, end_date: parsed.last, channel_id: 'channel').and_call_original
          message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'channel', text: "#{SlackRubyBot.config.user} stats yearly"))
        end
      end

      it 'parses quarterly' do
        allow(client.web_client).to receive(:chat_postMessage)
        Timecop.freeze do
          quarter_start = Time.now.beginning_of_quarter
          quarter_end_parsed = Chronic.parse('now', context: :past, guess: false)
          expect_any_instance_of(Team).to receive(:stats).with(
            start_date: quarter_start,
            end_date: quarter_end_parsed.last,
            channel_id: 'channel'
          ).and_call_original
          message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'channel', text: "#{SlackRubyBot.config.user} stats quarterly"))
        end
      end

      it 'parses since' do
        allow(client.web_client).to receive(:chat_postMessage)
        Timecop.freeze do
          start_date = Time.new(2023, 9, 1, 0, 0, 0)
          end_date = Time.now
          expect_any_instance_of(Team).to receive(:stats).with(start_date: start_date, end_date: end_date, channel_id: 'channel').and_call_original
          message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'channel', text: "#{SlackRubyBot.config.user} stats since September 2023"))
        end
      end

      it 'parses between' do
        allow(client.web_client).to receive(:chat_postMessage)
        start_date = Time.new(2023, 9, 1, 0, 0, 0)
        end_date = Time.new(2024, 9, 1, 0, 0, 0)
        expect_any_instance_of(Team).to receive(:stats).with(start_date: start_date, end_date: end_date, channel_id: 'channel').and_call_original
        message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'channel', text: "#{SlackRubyBot.config.user} stats between September 2023 and August 2024"))
      end

      it 'ignores it with an expression' do
        expect(client.web_client).to receive(:chat_postMessage)
        expect_any_instance_of(Team).to receive(:stats).with(channel_id: 'channel').and_call_original
        message_hook.call(client, Hashie::Mash.new(user: 'user', channel: 'channel', text: "#{SlackRubyBot.config.user} stats blah"))
      end
    end
  end
end
