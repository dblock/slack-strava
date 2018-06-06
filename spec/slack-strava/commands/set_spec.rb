require 'spec_helper'

describe SlackStrava::Commands::Set do
  let!(:team) { Fabricate(:team) }
  let(:app) { SlackStrava::Server.new(team: team) }
  let(:client) { app.send(:client) }
  let(:user) { Fabricate(:user, team: team) }
  before do
    allow(User).to receive(:find_create_or_update_by_slack_id!).and_return(user)
  end
  context 'units' do
    it 'requires a subscription' do
      expect(message: "#{SlackRubyBot.config.user} set units km").to respond_with_slack_message(team.subscribe_text)
    end
    context 'subscribed team' do
      let(:team) { Fabricate(:team, subscribed: true) }
      it 'errors on invalid setting' do
        expect(message: "#{SlackRubyBot.config.user} set whatever").to respond_with_slack_message(
          'Invalid setting whatever, type `help` for instructions.'
        )
      end
      it 'shows current settings' do
        expect(message: "#{SlackRubyBot.config.user} set").to respond_with_slack_message([
          "Activities for team #{team.name} display *miles*.",
          'Activity fields are *displayed as available*.',
          "Maps for team #{team.name} are *displayed in full*.",
          'Your private activities will not be posted.'
        ].join("\n"))
      end
      context 'private' do
        it 'shows current value of private' do
          expect(message: "#{SlackRubyBot.config.user} set private").to respond_with_slack_message(
            'Your private activities will not be posted.'
          )
        end
        it 'shows current value of private set to true' do
          user.update_attributes!(private_activities: true)
          expect(message: "#{SlackRubyBot.config.user} set private").to respond_with_slack_message(
            'Your private activities will be posted.'
          )
        end
        it 'sets private to false' do
          user.update_attributes!(private_activities: true)
          expect(message: "#{SlackRubyBot.config.user} set private false").to respond_with_slack_message(
            'Your private activities will no longer be posted.'
          )
          expect(user.reload.private_activities).to be false
        end
        it 'sets private to true' do
          expect(message: "#{SlackRubyBot.config.user} set private true").to respond_with_slack_message(
            'Your private activities will now be posted.'
          )
          expect(user.reload.private_activities).to be true
        end
      end
      context 'units' do
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
      context 'fields' do
        it 'shows current value of fields' do
          expect(message: "#{SlackRubyBot.config.user} set fields").to respond_with_slack_message(
            "Activity fields for team #{team.name} are *displayed as available*."
          )
        end
        it 'shows current value of fields set to Time and Elapsed Time' do
          team.update_attributes!(activity_fields: ['Time', 'Elapsed Time'])
          expect(message: "#{SlackRubyBot.config.user} set fields").to respond_with_slack_message(
            "Activity fields for team #{team.name} are *Time and Elapsed Time*."
          )
        end
        it 'changes fields' do
          expect(message: "#{SlackRubyBot.config.user} set fields Time, Elapsed Time").to respond_with_slack_message(
            "Activity fields for team #{team.name} are now *Time and Elapsed Time*."
          )
          expect(client.owner.activity_fields).to eq(['Time', 'Elapsed Time'])
          expect(team.reload.activity_fields).to eq(['Time', 'Elapsed Time'])
        end
        it 'sets fields to none' do
          expect(message: "#{SlackRubyBot.config.user} set fields none").to respond_with_slack_message(
            "Activity fields for team #{team.name} are now *not displayed*."
          )
          expect(client.owner.activity_fields).to eq(['None'])
          expect(team.reload.activity_fields).to eq(['None'])
        end
        it 'sets fields to all' do
          team.update_attributes!(activity_fields: ['None'])
          expect(message: "#{SlackRubyBot.config.user} set fields all").to respond_with_slack_message(
            "Activity fields for team #{team.name} are now *displayed as available*."
          )
          expect(client.owner.activity_fields).to eq(['All'])
          expect(team.reload.activity_fields).to eq(['All'])
        end
      end
    end
  end
end
