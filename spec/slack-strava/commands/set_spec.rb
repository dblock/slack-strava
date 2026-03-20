require 'spec_helper'

describe SlackStrava::Commands::Set do
  let!(:team) { Fabricate(:team, created_at: 2.weeks.ago) }
  let(:app) { SlackStrava::Server.new(team: team) }
  let(:client) { app.send(:client) }
  let(:user) { Fabricate(:user, team: team, is_admin: true) }

  before do
    allow(User).to receive(:find_create_or_update_by_slack_id!).and_return(user)
  end

  context 'settings' do
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

      it 'shows current settings in a DM' do
        expect(message: "#{SlackRubyBot.config.user} set").to respond_with_slack_message([
          "Activities for team #{team.name} display *miles, feet, yards, and degrees Fahrenheit*.",
          'Activities are *displayed individually*.',
          'Activities are retained for *1 month*.',
          "Timezone is *#{team.timezone_s}*.",
          'Max activities per user per day are *unlimited*.',
          'Max activities per channel per day are *unlimited*.',
          'Activity fields are *set to default*.',
          'Maps are *displayed in full*.',
          'Default leaderboard is *distance*.',
          'Your activities will *sync*.',
          'Your private activities will *not be posted*.',
          'Your followers only activities will *be posted*.'
        ].join("\n"))
      end

      it 'shows current settings in a channel' do
        expect(message: "#{SlackRubyBot.config.user} set", channel: 'C1').to respond_with_slack_message([
          "Activities for team #{team.name} display *miles, feet, yards, and degrees Fahrenheit*.",
          'Activities are *displayed individually*.',
          'Activities are retained for *1 month*.',
          "Timezone is *#{team.timezone_s}*.",
          'Max activities per user per day are *unlimited*.',
          'Max activities per channel per day are *unlimited*.',
          'Activity fields are *set to default*.',
          'Maps are *displayed in full*.',
          'Default leaderboard is *distance*.',
          'Your activities will *sync* in <#C1>.',
          'Activity types for <#C1> are *all*.',
          'Your private activities will *not be posted*.',
          'Your followers only activities will *be posted*.'
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
              allow_any_instance_of(User).to receive(:connected_channels).and_return([{ 'id' => 'C1' }])
              allow_any_instance_of(User).to receive(:inform_channel!).and_return([{ ts: 'ts', channel: 'C1' }])
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

        context 'per channel' do
          before do
            allow_any_instance_of(Slack::Web::Client).to receive(:conversations_info)
              .with(channel: 'C1')
              .and_return(Hashie::Mash.new(channel: { 'id' => 'C1', 'name' => 'general' }))
          end

          it 'shows default sync in channel' do
            expect(message: "#{SlackRubyBot.config.user} set sync", channel: 'C1').to respond_with_slack_message(
              'Your activities will sync in <#C1>.'
            )
          end

          it 'disables sync in channel' do
            expect(message: "#{SlackRubyBot.config.user} set sync false", channel: 'C1').to respond_with_slack_message(
              'Your activities will no longer sync in <#C1>.'
            )
            expect(user.reload.sync_activities_for_channel?('C1')).to be false
            expect(user.reload.sync_activities).to be true
          end

          it 'enables sync in channel' do
            user.set_user_channel!('C1', 'general', sync_activities: false)
            expect(message: "#{SlackRubyBot.config.user} set sync true", channel: 'C1').to respond_with_slack_message(
              'Your activities will now sync in <#C1>.'
            )
            expect(user.reload.sync_activities_for_channel?('C1')).to be true
          end

          it 'falls back to global sync setting in channel' do
            user.update_attributes!(sync_activities: false)
            expect(message: "#{SlackRubyBot.config.user} set sync", channel: 'C1').to respond_with_slack_message(
              'Your activities will not sync in <#C1>.'
            )
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

      context 'followers only' do
        it 'shows current value of followers_only' do
          expect(message: "#{SlackRubyBot.config.user} set followers").to respond_with_slack_message(
            'Your followers only activities will be posted.'
          )
        end

        it 'shows current value of followers only set to false' do
          user.update_attributes!(followers_only_activities: false)
          expect(message: "#{SlackRubyBot.config.user} set followers").to respond_with_slack_message(
            'Your followers only activities will not be posted.'
          )
        end

        it 'sets followers only to false' do
          user.update_attributes!(followers_only_activities: true)
          expect(message: "#{SlackRubyBot.config.user} set followers false").to respond_with_slack_message(
            'Your followers only activities will no longer be posted.'
          )
          expect(user.reload.followers_only_activities).to be false
        end

        it 'sets followers only to true' do
          user.update_attributes!(followers_only_activities: false)
          expect(message: "#{SlackRubyBot.config.user} set followers true").to respond_with_slack_message(
            'Your followers only activities will now be posted.'
          )
          expect(user.reload.followers_only_activities).to be true
        end
      end

      context 'as team admin' do
        context 'units' do
          it 'shows current value of units' do
            expect(message: "#{SlackRubyBot.config.user} set units").to respond_with_slack_message(
              "Activities for team #{team.name} display *miles, feet, yards, and degrees Fahrenheit*."
            )
          end

          it 'shows current value of units set to km' do
            team.update_attributes!(units: 'km')
            expect(message: "#{SlackRubyBot.config.user} set units").to respond_with_slack_message(
              "Activities for team #{team.name} display *kilometers, meters, and degrees Celsius*."
            )
          end

          it 'sets units to mi' do
            team.update_attributes!(units: 'km')
            expect(message: "#{SlackRubyBot.config.user} set units mi").to respond_with_slack_message(
              "Activities for team #{team.name} now display *miles, feet, yards, and degrees Fahrenheit*."
            )
            expect(client.owner.units).to eq 'mi'
            expect(team.reload.units).to eq 'mi'
          end

          it 'sets units to km' do
            team.update_attributes!(units: 'mi')
            expect(message: "#{SlackRubyBot.config.user} set units km").to respond_with_slack_message(
              "Activities for team #{team.name} now display *kilometers, meters, and degrees Celsius*."
            )
            expect(client.owner.units).to eq 'km'
            expect(team.reload.units).to eq 'km'
          end

          it 'sets units to metric' do
            team.update_attributes!(units: 'mi')
            expect(message: "#{SlackRubyBot.config.user} set units metric").to respond_with_slack_message(
              "Activities for team #{team.name} now display *kilometers, meters, and degrees Celsius*."
            )
            expect(client.owner.units).to eq 'km'
            expect(team.reload.units).to eq 'km'
          end

          it 'sets units to imperial' do
            team.update_attributes!(units: 'km')
            expect(message: "#{SlackRubyBot.config.user} set units imperial").to respond_with_slack_message(
              "Activities for team #{team.name} now display *miles, feet, yards, and degrees Fahrenheit*."
            )
            expect(client.owner.units).to eq 'mi'
            expect(team.reload.units).to eq 'mi'
          end

          it 'changes units' do
            team.update_attributes!(units: 'mi')
            expect(message: "#{SlackRubyBot.config.user} set units km").to respond_with_slack_message(
              "Activities for team #{team.name} now display *kilometers, meters, and degrees Celsius*."
            )
            expect(client.owner.units).to eq 'km'
            expect(team.reload.units).to eq 'km'
          end

          it 'shows current value of units set to both' do
            team.update_attributes!(units: 'both')
            expect(message: "#{SlackRubyBot.config.user} set units").to respond_with_slack_message(
              "Activities for team #{team.name} display *both units*."
            )
          end

          it 'sets units to both' do
            team.update_attributes!(units: 'km')
            expect(message: "#{SlackRubyBot.config.user} set units both").to respond_with_slack_message(
              "Activities for team #{team.name} now display *both units*."
            )
            expect(client.owner.units).to eq 'both'
            expect(team.reload.units).to eq 'both'
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

        context 'threads' do
          it 'shows current value of threads' do
            expect(message: "#{SlackRubyBot.config.user} set threads").to respond_with_slack_message(
              "Activities for team #{team.name} are *displayed individually*."
            )
          end

          it 'shows current value of threads set to weekly' do
            team.update_attributes!(threads: 'weekly')
            expect(message: "#{SlackRubyBot.config.user} set threads").to respond_with_slack_message(
              "Activities for team #{team.name} are *rolled up in a weekly thread*."
            )
          end

          %w[daily weekly monthly].each do |threads|
            it "sets threads to #{threads}" do
              team.update_attributes!(threads: 'none')
              expect(message: "#{SlackRubyBot.config.user} set threads #{threads}").to respond_with_slack_message(
                "Activities for team #{team.name} are now *rolled up in a #{threads} thread*."
              )
              expect(team.reload.threads).to eq threads
            end
          end

          it 'sets threads to none' do
            team.update_attributes!(threads: 'daily')
            expect(message: "#{SlackRubyBot.config.user} set threads none").to respond_with_slack_message(
              "Activities for team #{team.name} are now *displayed individually*."
            )
            expect(team.reload.threads).to eq 'none'
          end

          it 'displays an error for an invalid threads value' do
            expect(message: "#{SlackRubyBot.config.user} set threads foobar").to respond_with_slack_message(
              'Invalid value: foobar, possible values are none, daily, weekly and monthly.'
            )
            expect(team.reload.threads).to eq 'none'
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
              'Invalid fields: Foo and Bar, possible values are Default, All, None, Type, Distance, Time, Moving Time, Elapsed Time, Pace, Speed, Elevation, Max Speed, Heart Rate, Max Heart Rate, PR Count, Calories, Weather, Photos, Device, Gear, Title, Description, Url, User, Medal, Athlete and Date.'
            )
            expect(team.reload.activity_fields).to eq ['Default']
          end

          context 'some' do
            it 'sets fields to some' do
              expect(message: "#{SlackRubyBot.config.user} set fields Title, Url, PR Count, Elapsed Time").to respond_with_slack_message(
                "Activity fields for team #{team.name} are now *Title, Url, PR Count and Elapsed Time*."
              )
              expect(team.reload.activity_fields).to eq(['Title', 'Url', 'PR Count', 'Elapsed Time'])
            end
          end

          context 'each field' do
            (ActivityFields.values - [ActivityFields::ALL, ActivityFields::DEFAULT, ActivityFields::NONE]).each do |field|
              context field do
                it "sets fields to #{field}" do
                  expect(message: "#{SlackRubyBot.config.user} set fields #{field}").to respond_with_slack_message(
                    "Activity fields for team #{team.name} are now *#{field}*."
                  )
                  expect(team.reload.activity_fields).to eq([field])
                end
              end
            end
          end

          context 'leaderboard' do
            it 'shows current value of leaderboard' do
              expect(message: "#{SlackRubyBot.config.user} set leaderboard").to respond_with_slack_message(
                "Default leaderboard for team #{team.name} is *distance*."
              )
            end

            it 'shows current value of leaderboard as set' do
              team.update_attributes!(default_leaderboard: 'elapsed time')
              expect(message: "#{SlackRubyBot.config.user} set leaderboard").to respond_with_slack_message(
                "Default leaderboard for team #{team.name} is *elapsed time*."
              )
            end

            it 'sets leaderboard to elapsed time' do
              team.update_attributes!(default_leaderboard: 'distance')
              expect(message: "#{SlackRubyBot.config.user} set leaderboard elapsed time").to respond_with_slack_message(
                "Default leaderboard for team #{team.name} is now *elapsed time*."
              )
              expect(team.reload.default_leaderboard).to eq 'elapsed time'
            end

            it 'displays an error for an invalid leaderboard value' do
              team.update_attributes!(default_leaderboard: 'distance')
              expect(message: "#{SlackRubyBot.config.user} set leaderboard foobar").to respond_with_slack_message(
                "Sorry, I don't understand 'foobar'."
              )
              expect(team.reload.default_leaderboard).to eq 'distance'
            end
          end

          context 'retention' do
            it 'shows current retention value' do
              expect(message: "#{SlackRubyBot.config.user} set retention").to respond_with_slack_message(
                "Activities in team #{team.name} are retained for *1 month*."
              )
            end

            it 'shows changed retention value' do
              team.update_attributes!(retention: 15 * 24 * 60 * 60)
              expect(message: "#{SlackRubyBot.config.user} set retention").to respond_with_slack_message(
                "Activities in team #{team.name} are retained for *15 days*."
              )
            end

            it 'sets retention' do
              expect(message: "#{SlackRubyBot.config.user} set retention 7 days").to respond_with_slack_message(
                "Activities in team #{team.name} are now retained for *7 days*."
              )
              expect(team.reload.retention).to eq 7 * 24 * 60 * 60
            end

            it 'displays an error for an invalid retention value' do
              expect(message: "#{SlackRubyBot.config.user} set retention foobar").to respond_with_slack_message(
                'An invalid word "foobar" was used in the string to be parsed.'
              )
              expect(team.reload.retention).to eq 30 * 24 * 60 * 60
            end
          end

          context 'timezone' do
            it 'shows current timezone' do
              expect(message: "#{SlackRubyBot.config.user} set timezone").to respond_with_slack_message(
                "Timezone for team #{team.name} is *auto (Eastern Time (US & Canada))*."
              )
            end

            it 'sets timezone' do
              expect(message: "#{SlackRubyBot.config.user} set timezone Hawaii").to respond_with_slack_message(
                "Timezone for team #{team.name} is now *#{ActiveSupport::TimeZone.new('Hawaii')}*."
              )
              expect(team.reload.timezone).to eq 'Hawaii'
            end

            it 'shows a changed timezone' do
              team.update_attributes!(timezone: 'Hawaii')
              expect(message: "#{SlackRubyBot.config.user} set timezone").to respond_with_slack_message(
                "Timezone for team #{team.name} is *#{ActiveSupport::TimeZone.new('Hawaii')}*."
              )
            end

            it 'errors on an invalid timezone' do
              expect(message: "#{SlackRubyBot.config.user} set timezone foobar").to respond_with_slack_message(
                "TimeZone _foobar_ is invalid, see https://github.com/rails/rails/blob/v#{ActiveSupport.gem_version}/activesupport/lib/active_support/values/time_zone.rb#L30 for a list. Timezone for team #{team.name} is currently *auto (Eastern Time (US & Canada))*."
              )
              expect(team.reload.timezone).to eq 'auto'
            end

            it 'sets timezone to auto' do
              team.update_attributes!(timezone: 'Hawaii')
              Fabricate(:user_activity, team: team, user: user, timezone: '(GMT-08:00) America/Los_Angeles')
              expect(message: "#{SlackRubyBot.config.user} set timezone auto").to respond_with_slack_message(
                "Timezone for team #{team.name} is now *auto (Pacific Time (US & Canada))*."
              )
              expect(team.reload.timezone).to eq 'auto'
            end

            it 'shows auto timezone with no activities' do
              expect(message: "#{SlackRubyBot.config.user} set timezone auto").to respond_with_slack_message(
                "Timezone for team #{team.name} is *auto (Eastern Time (US & Canada))*."
              )
              expect(team.reload.timezone).to eq 'auto'
            end
          end

          context 'userlimit' do
            it 'shows current value as unlimited' do
              expect(message: "#{SlackRubyBot.config.user} set userlimit").to respond_with_slack_message(
                "Max activities per user per day for team #{team.name} are *unlimited*."
              )
            end

            it 'shows a configured value' do
              team.update_attributes!(max_activities_per_user_per_day: 5)
              expect(message: "#{SlackRubyBot.config.user} set userlimit").to respond_with_slack_message(
                "Max activities per user per day for team #{team.name} are *5 per day*."
              )
            end

            it 'sets a limit' do
              expect(message: "#{SlackRubyBot.config.user} set userlimit 3").to respond_with_slack_message(
                "Max activities per user per day for team #{team.name} are now *3 per day*."
              )
              expect(team.reload.max_activities_per_user_per_day).to eq 3
            end

            it 'clears the limit with none' do
              team.update_attributes!(max_activities_per_user_per_day: 3)
              expect(message: "#{SlackRubyBot.config.user} set userlimit none").to respond_with_slack_message(
                "Max activities per user per day for team #{team.name} are now *unlimited*."
              )
              expect(team.reload.max_activities_per_user_per_day).to be_nil
            end

            it 'displays an error for an invalid value' do
              expect(message: "#{SlackRubyBot.config.user} set userlimit foobar").to respond_with_slack_message(
                "Invalid value: foobar. Please use a positive number or 'none'."
              )
              expect(team.reload.max_activities_per_user_per_day).to be_nil
            end
          end

          context 'activities' do
            before do
              allow_any_instance_of(Slack::Web::Client).to receive(:conversations_info)
                .with(channel: 'C1')
                .and_return(Hashie::Mash.new(channel: { 'id' => 'C1', 'name' => 'running' }))
            end

            it 'shows all activity types by default in channel' do
              expect(message: "#{SlackRubyBot.config.user} set activities", channel: 'C1').to respond_with_slack_message(
                'Activity types for <#C1> are *all*.'
              )
            end

            it 'sets activity types in a channel' do
              expect(message: "#{SlackRubyBot.config.user} set activities Run,Ride", channel: 'C1').to respond_with_slack_message(
                'Activity types for <#C1> are now *Run, Ride*.'
              )
              expect(team.reload.channel_activity_types_for('C1')).to eq %w[Run Ride]
            end

            it 'sets activity types with space separator' do
              expect(message: "#{SlackRubyBot.config.user} set activities Run Ride", channel: 'C1').to respond_with_slack_message(
                'Activity types for <#C1> are now *Run, Ride*.'
              )
              expect(team.reload.channel_activity_types_for('C1')).to eq %w[Run Ride]
            end

            it 'sets activity types case-insensitively' do
              expect(message: "#{SlackRubyBot.config.user} set activities run", channel: 'C1').to respond_with_slack_message(
                'Activity types for <#C1> are now *Run*.'
              )
              expect(team.reload.channel_activity_types_for('C1')).to eq ['Run']
            end

            it 'resets to all with "all"' do
              team.set_channel!('C1', 'running', activity_types: ['Run'])
              expect(message: "#{SlackRubyBot.config.user} set activities all", channel: 'C1').to respond_with_slack_message(
                'Activity types for <#C1> are now *all*.'
              )
              expect(team.reload.channel_activity_types_for('C1')).to eq []
            end

            it 'displays an error for an unknown activity type' do
              expect(message: "#{SlackRubyBot.config.user} set activities Foo", channel: 'C1').to respond_with_slack_message(
                "Invalid activity type: Foo. Use: #{ActivityMethods::ACTIVITY_TYPES.or}."
              )
            end

            it 'cannot be set in a DM' do
              expect(message: "#{SlackRubyBot.config.user} set activities Run").to respond_with_slack_message(
                'You can only set activity types in a channel, not a DM.'
              )
            end
          end

          context 'channellimit' do
            it 'shows current value as unlimited' do
              expect(message: "#{SlackRubyBot.config.user} set channellimit").to respond_with_slack_message(
                "Max activities per channel per day for team #{team.name} are *unlimited*."
              )
            end

            it 'shows a configured value' do
              team.update_attributes!(max_activities_per_channel_per_day: 10)
              expect(message: "#{SlackRubyBot.config.user} set channellimit").to respond_with_slack_message(
                "Max activities per channel per day for team #{team.name} are *10 per day*."
              )
            end

            it 'sets a limit' do
              expect(message: "#{SlackRubyBot.config.user} set channellimit 10").to respond_with_slack_message(
                "Max activities per channel per day for team #{team.name} are now *10 per day*."
              )
              expect(team.reload.max_activities_per_channel_per_day).to eq 10
            end

            it 'clears the limit with none' do
              team.update_attributes!(max_activities_per_channel_per_day: 10)
              expect(message: "#{SlackRubyBot.config.user} set channellimit none").to respond_with_slack_message(
                "Max activities per channel per day for team #{team.name} are now *unlimited*."
              )
              expect(team.reload.max_activities_per_channel_per_day).to be_nil
            end

            it 'displays an error for an invalid value' do
              expect(message: "#{SlackRubyBot.config.user} set channellimit foobar").to respond_with_slack_message(
                "Invalid value: foobar. Please use a positive number or 'none'."
              )
              expect(team.reload.max_activities_per_channel_per_day).to be_nil
            end
          end
        end

        context 'not as a team admin' do
          let(:user) { Fabricate(:user, team: team) }

          context 'timezone' do
            it 'shows current timezone' do
              expect(message: "#{SlackRubyBot.config.user} set timezone").to respond_with_slack_message(
                "Timezone for team #{team.name} is *auto (Eastern Time (US & Canada))*."
              )
            end

            it 'cannot set timezone' do
              expect(message: "#{SlackRubyBot.config.user} set timezone Hawaii").to respond_with_slack_message(
                "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change the timezone. Timezone for team #{team.name} is *auto (Eastern Time (US & Canada))*."
              )
              expect(team.reload.timezone).to eq 'auto'
            end

            it 'cannot auto-detect timezone' do
              team.update_attributes!(timezone: 'Hawaii')
              Fabricate(:user_activity, team: team, user: user, timezone: '(GMT-08:00) America/Los_Angeles')
              expect(message: "#{SlackRubyBot.config.user} set timezone auto").to respond_with_slack_message(
                "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change the timezone. Timezone for team #{team.name} is *#{ActiveSupport::TimeZone.new('Hawaii')}*."
              )
              expect(team.reload.timezone).to eq 'Hawaii'
            end
          end

          context 'units' do
            it 'shows current value of units' do
              expect(message: "#{SlackRubyBot.config.user} set units").to respond_with_slack_message(
                "Activities for team #{team.name} display *miles, feet, yards, and degrees Fahrenheit*."
              )
            end

            it 'cannot set units' do
              team.update_attributes!(units: 'km')
              expect(message: "#{SlackRubyBot.config.user} set units mi").to respond_with_slack_message(
                "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change units. Activities for team #{team.name} display *kilometers, meters, and degrees Celsius*."
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

          context 'leaderboard' do
            it 'shows current value of leaderboard' do
              expect(message: "#{SlackRubyBot.config.user} set leaderboard").to respond_with_slack_message(
                "Default leaderboard for team #{team.name} is *distance*."
              )
            end

            it 'cannot set leaderboard' do
              team.update_attributes!(default_leaderboard: 'elapsed time')
              expect(message: "#{SlackRubyBot.config.user} set leaderboard distance").to respond_with_slack_message(
                "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change the default leaderboard. Default leaderboard for team #{team.name} is *elapsed time*."
              )
              expect(client.owner.default_leaderboard).to eq('elapsed time')
            end
          end

          context 'retention' do
            it 'shows current value of retention' do
              expect(message: "#{SlackRubyBot.config.user} set retention").to respond_with_slack_message(
                "Activities in team #{team.name} are retained for *1 month*."
              )
            end

            it 'cannot set leaderboard' do
              expect(message: "#{SlackRubyBot.config.user} set retention 5 days").to respond_with_slack_message(
                "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change activity retention. Activities in team #{team.name} are retained for *1 month*."
              )
              expect(client.owner.retention).to eq(30 * 24 * 60 * 60)
            end
          end

          context 'userlimit' do
            it 'shows current value' do
              expect(message: "#{SlackRubyBot.config.user} set userlimit").to respond_with_slack_message(
                "Max activities per user per day for team #{team.name} are *unlimited*."
              )
            end

            it 'cannot set userlimit' do
              expect(message: "#{SlackRubyBot.config.user} set userlimit 5").to respond_with_slack_message(
                "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change the max activities per user per day. Max activities per user per day for team #{team.name} are *unlimited*."
              )
              expect(team.reload.max_activities_per_user_per_day).to be_nil
            end
          end

          context 'activities' do
            before do
              allow_any_instance_of(Slack::Web::Client).to receive(:conversations_info)
                .with(channel: 'C1')
                .and_return(Hashie::Mash.new(channel: { 'id' => 'C1', 'name' => 'running' }))
            end

            it 'shows current activity types' do
              expect(message: "#{SlackRubyBot.config.user} set activities", channel: 'C1').to respond_with_slack_message(
                'Activity types for <#C1> are *all*.'
              )
            end

            it 'cannot set activity types' do
              expect(message: "#{SlackRubyBot.config.user} set activities Run", channel: 'C1').to respond_with_slack_message(
                "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change activity types for a channel. Activity types for <#C1> are *all*."
              )
              expect(team.reload.channel_activity_types_for('C1')).to eq []
            end
          end

          context 'channellimit' do
            it 'shows current value' do
              expect(message: "#{SlackRubyBot.config.user} set channellimit").to respond_with_slack_message(
                "Max activities per channel per day for team #{team.name} are *unlimited*."
              )
            end

            it 'cannot set channellimit' do
              expect(message: "#{SlackRubyBot.config.user} set channellimit 10").to respond_with_slack_message(
                "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change the max activities per channel per day. Max activities per channel per day for team #{team.name} are *unlimited*."
              )
              expect(team.reload.max_activities_per_channel_per_day).to be_nil
            end
          end
        end
      end
    end
  end
end
