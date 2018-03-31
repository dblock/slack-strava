require 'spec_helper'

describe SlackStrava::Commands::Set do
  let!(:team) { Fabricate(:team) }
  let(:app) { SlackStrava::Server.new(team: team) }
  let(:client) { app.send(:client) }
  context 'units' do
    it 'requires a subscription' do
      expect(message: "#{SlackRubyBot.config.user} set units km").to respond_with_slack_message(team.subscribe_text)
    end
    context 'subscribed team' do
      let(:team) { Fabricate(:team, subscribed: true) }
      it 'shows current value of units' do
        expect(message: "#{SlackRubyBot.config.user} set units").to respond_with_slack_message(
          "Activities for team #{team.name} display *miles*."
        )
      end
      it 'shows current value of units set to km' do
        team.update_attributes!(units: 'km')
        expect(message: "#{SlackRubyBot.config.user} set units").to respond_with_slack_message(
          "Activities for team #{team.name} display *kilometers*."
        )
      end
      it 'sets units to mi' do
        team.update_attributes!(units: 'km')
        expect(message: "#{SlackRubyBot.config.user} set units mi").to respond_with_slack_message(
          "Activities for team #{team.name} now display *miles*."
        )
        expect(client.owner.units).to eq 'mi'
        expect(team.reload.units).to eq 'mi'
      end
      it 'changes units' do
        team.update_attributes!(units: 'mi')
        expect(message: "#{SlackRubyBot.config.user} set units km").to respond_with_slack_message(
          "Activities for team #{team.name} now display *kilometers*."
        )
        expect(client.owner.units).to eq 'km'
        expect(team.reload.units).to eq 'km'
      end
    end
  end
end
