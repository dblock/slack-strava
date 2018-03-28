require 'spec_helper'

describe SlackStrava::Commands::Help do
  let(:app) { SlackStrava::Server.new(team: team) }
  let(:client) { app.send(:client) }
  let(:message_hook) { SlackRubyBot::Hooks::Message.new }
  context 'subscribed team' do
    let!(:team) { Fabricate(:team, subscribed: true) }
    it 'help' do
      expect(client).to receive(:say).with(channel: 'channel', text: [SlackStrava::Commands::Help::HELP, SlackStrava::INFO].join("\n"))
      expect(client).to receive(:say).with(channel: 'channel', gif: 'help')
      message_hook.call(client, Hashie::Mash.new(channel: 'channel', text: "#{SlackRubyBot.config.user} help"))
    end
  end
  context 'non-subscribed team after trial' do
    let!(:team) { Fabricate(:team, created_at: 2.weeks.ago) }
    it 'help' do
      expect(client).to receive(:say).with(channel: 'channel', text: [
        SlackStrava::Commands::Help::HELP,
        SlackStrava::INFO,
        [team.send(:trial_expired_text), team.send(:subscribe_team_text)].join(' ')
      ].join("\n"))
      expect(client).to receive(:say).with(channel: 'channel', gif: 'help')
      message_hook.call(client, Hashie::Mash.new(channel: 'channel', text: "#{SlackRubyBot.config.user} help"))
    end
  end
  context 'non-subscribed team during trial' do
    let!(:team) { Fabricate(:team, created_at: 1.day.ago) }
    it 'help' do
      expect(client).to receive(:say).with(channel: 'channel', text: [
        SlackStrava::Commands::Help::HELP,
        SlackStrava::INFO,
        team.send(:subscribe_team_text)
      ].join("\n"))
      expect(client).to receive(:say).with(channel: 'channel', gif: 'help')
      message_hook.call(client, Hashie::Mash.new(channel: 'channel', text: "#{SlackRubyBot.config.user} help"))
    end
  end
end
