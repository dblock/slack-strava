require 'spec_helper'

describe SlackStrava::Commands::Set do
  let!(:team) { Fabricate(:team, created_at: 2.weeks.ago) }
  let(:app) { SlackStrava::Server.new(team: team) }
  let(:client) { app.send(:client) }
  let(:user) { Fabricate(:user, team: team, is_admin: true) }
  before do
    allow(User).to receive(:find_create_or_update_by_slack_id!).and_return(user)
  end
  context 'units' do
    it 'requires a subscription' do
      expect(message: "#{SlackRubyBot.config.user} set units km").to respond_with_slack_message(team.trial_message)
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
          'Activity fields are *set to default*.',
          "Maps for team #{team.name} are *displayed in full*.",
          'Your activities will sync.',
          'Your private activities will not be posted.'
        ].join("\n"))
      end
      context 'sync' do
        it 'shows default value of sync' do
          expect(message: "#{SlackRubyBot.config.user} set sync").to respond_with_slack_message(
            'Your activities will sync.'
          )
        end
        it 'shows current value of sync set to true' do
          user.update_attributes!(sync_activities: true)
          expect(message: "#{SlackRubyBot.config.user} set sync").to respond_with_slack_message(
            'Your activities will sync.'
          )
        end
        it 'sets sync to false' do
          user.update_attributes!(sync_activities: true)
          expect(message: "#{SlackRubyBot.config.user} set sync false").to respond_with_slack_message(
            'Your activities will no longer sync.'
          )
          expect(user.reload.sync_activities).to be false
        end
        context 'with sync set to false' do
          before do
            user.update_attributes!(sync_activities: false)
          end
          it 'sets sync to true' do
            expect(message: "#{SlackRubyBot.config.user} set sync true").to respond_with_slack_message(
              'Your activities will now sync.'
            )
            expect(user.reload.sync_activities).to be true
          end
          context 'with prior activities' do
            before do
              allow_any_instance_of(Map).to receive(:update_png!)
              allow_any_instance_of(User).to receive(:inform!).and_return([{ ts: 'ts', channel: 'C1' }])
              2.times { Fabricate(:user_activity, user: user) }
              user.brag!
            end
            it 'resets all activities' do
              expect {
                expect {
                  expect(message: "#{SlackRubyBot.config.user} set sync true").to respond_with_slack_message(
                    'Your activities will now sync.'
                  )
                }.to change(user.activities, :count).by(-2)
              }.to change(user, :activities_at)
            end
          end
        end
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
      context 'as team admin' do
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
        context 'maps' do
          it 'shows current value of maps' do
            expect(message: "#{SlackRubyBot.config.user} set maps").to respond_with_slack_message(
              "Maps for team #{team.name} are *displayed in full*."
            )
          end
          it 'shows current value of maps set to thumb' do
            team.update_attributes!(maps: 'thumb')
            expect(message: "#{SlackRubyBot.config.user} set maps").to respond_with_slack_message(
              "Maps for team #{team.name} are *displayed as thumbnails*."
            )
          end
          it 'sets maps to thumb' do
            team.update_attributes!(maps: 'off')
            expect(message: "#{SlackRubyBot.config.user} set maps thumb").to respond_with_slack_message(
              "Maps for team #{team.name} are now *displayed as thumbnails*."
            )
            expect(team.reload.maps).to eq 'thumb'
          end
          it 'sets maps to off' do
            expect(message: "#{SlackRubyBot.config.user} set maps off").to respond_with_slack_message(
              "Maps for team #{team.name} are now *not displayed*."
            )
            expect(team.reload.maps).to eq 'off'
          end
          it 'displays an error for an invalid maps value' do
            expect(message: "#{SlackRubyBot.config.user} set maps foobar").to respond_with_slack_message(
              'Invalid value: foobar, possible values are full, off and thumb.'
            )
            expect(team.reload.maps).to eq 'full'
          end
        end
        context 'fields' do
          it 'shows current value of fields' do
            expect(message: "#{SlackRubyBot.config.user} set fields").to respond_with_slack_message(
              "Activity fields for team #{team.name} are *set to default*."
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
              "Activity fields for team #{team.name} are now *all displayed if available*."
            )
            expect(client.owner.activity_fields).to eq(['All'])
            expect(team.reload.activity_fields).to eq(['All'])
          end
          it 'sets fields to default' do
            team.update_attributes!(activity_fields: ['All'])
            expect(message: "#{SlackRubyBot.config.user} set fields default").to respond_with_slack_message(
              "Activity fields for team #{team.name} are now *set to default*."
            )
            expect(client.owner.activity_fields).to eq(['Default'])
            expect(team.reload.activity_fields).to eq(['Default'])
          end
          it 'sets to invalid fields' do
            expect(message: "#{SlackRubyBot.config.user} set fields Time, Foo, Bar").to respond_with_slack_message(
              'Invalid fields: Foo and Bar, possible values are Default, All, None, Type, Distance, Time, Moving Time, Elapsed Time, Pace, Speed, Elevation, Max Speed, Heart Rate, Max Heart Rate, PR Count, Calories and Weather.'
            )
            expect(team.reload.activity_fields).to eq ['Default']
          end
        end
        context 'not as a team admin' do
          let(:user) { Fabricate(:user, team: team) }
          context 'units' do
            it 'shows current value of units' do
              expect(message: "#{SlackRubyBot.config.user} set units").to respond_with_slack_message(
                "Activities for team #{team.name} display *miles*."
              )
            end
            it 'cannot set units' do
              team.update_attributes!(units: 'km')
              expect(message: "#{SlackRubyBot.config.user} set units mi").to respond_with_slack_message(
                "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change units. Activities for team #{team.name} display *kilometers*."
              )
              expect(team.reload.units).to eq 'km'
            end
          end
          context 'maps' do
            it 'shows current value of maps' do
              expect(message: "#{SlackRubyBot.config.user} set maps").to respond_with_slack_message(
                "Maps for team #{team.name} are *displayed in full*."
              )
            end
            it 'cannot set maps' do
              team.update_attributes!(maps: 'full')
              expect(message: "#{SlackRubyBot.config.user} set maps off").to respond_with_slack_message(
                "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change maps. Maps for team #{team.name} are *displayed in full*."
              )
              expect(team.reload.maps).to eq 'full'
            end
          end
          context 'fields' do
            it 'shows current value of fields' do
              expect(message: "#{SlackRubyBot.config.user} set fields").to respond_with_slack_message(
                "Activity fields for team #{team.name} are *set to default*."
              )
            end
            it 'cannot set fields' do
              team.update_attributes!(activity_fields: ['None'])
              expect(message: "#{SlackRubyBot.config.user} set fields all").to respond_with_slack_message(
                "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change fields. Activity fields for team #{team.name} are *not displayed*."
              )
              expect(client.owner.activity_fields).to eq(['None'])
            end
          end
        end
      end
    end
  end
end
