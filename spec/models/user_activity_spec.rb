require 'spec_helper'

describe UserActivity do
  before do
    allow(HTTParty).to receive_message_chain(:get, :body).and_return('PNG')
  end

  context 'hidden?' do
    context 'default' do
      let(:activity) { Fabricate(:user_activity) }

      it 'is not hidden' do
        expect(activity.hidden?).to be false
      end
    end

    context 'private' do
      context 'private and user is private' do
        let(:user) { Fabricate(:user, private_activities: false) }
        let(:activity) { Fabricate(:user_activity, user: user, private: true) }

        it 'is hidden' do
          expect(activity.hidden?).to be true
        end
      end

      context 'private but user is public' do
        let(:user) { Fabricate(:user, private_activities: true) }
        let(:activity) { Fabricate(:user_activity, user: user, private: true) }

        it 'is not hidden' do
          expect(activity.hidden?).to be false
        end
      end

      context 'public but user is private' do
        let(:user) { Fabricate(:user, private_activities: false) }
        let(:activity) { Fabricate(:user_activity, user: user, private: false) }

        it 'is hidden' do
          expect(activity.hidden?).to be false
        end
      end
    end

    context 'visibility' do
      context 'user has not set followers_only_activities' do
        let(:user) { Fabricate(:user, followers_only_activities: false) }

        context 'only_me' do
          let(:activity) { Fabricate(:user_activity, user: user, visibility: 'only_me') }

          it 'is hidden' do
            expect(activity.hidden?).to be true
          end
        end

        context 'followers_only' do
          let(:activity) { Fabricate(:user_activity, user: user, visibility: 'followers_only') }

          it 'is hidden' do
            expect(activity.hidden?).to be true
          end
        end

        context 'everyone' do
          let(:activity) { Fabricate(:user_activity, user: user, visibility: 'everyone') }

          it 'is not hidden' do
            expect(activity.hidden?).to be false
          end
        end
      end

      context 'user has set followers_only_activities' do
        let(:user) { Fabricate(:user, followers_only_activities: true) }

        context 'only_me' do
          let(:activity) { Fabricate(:user_activity, user: user, visibility: 'only_me') }

          it 'is hidden' do
            expect(activity.hidden?).to be true
          end
        end

        context 'followers_only' do
          let(:activity) { Fabricate(:user_activity, user: user, visibility: 'followers_only') }

          it 'is not hidden' do
            expect(activity.hidden?).to be false
          end
        end

        context 'everyone' do
          let(:activity) { Fabricate(:user_activity, user: user, visibility: 'everyone') }

          it 'is not hidden' do
            expect(activity.hidden?).to be false
          end
        end
      end
    end
  end

  context 'brag!' do
    let(:team) { Fabricate(:team) }
    let(:user) { Fabricate(:user, team: team) }
    let!(:activity) { Fabricate(:user_activity, user: user) }

    before do
      allow_any_instance_of(Team).to receive(:slack_channels).and_return(['id' => 'channel_id'])
      allow_any_instance_of(User).to receive(:user_deleted?).and_return(false)
      allow_any_instance_of(User).to receive(:user_in_channel?).and_return(true)
      allow_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).and_return('ts' => '1503435956.000247')
    end

    it 'sends a message to the subscribed channel' do
      expect(user.team.slack_client).to receive(:chat_postMessage).with(
        activity.to_slack.merge(
          as_user: true,
          channel: 'channel_id'
        )
      ).and_return('ts' => 1)
      expect(activity.brag!).to eq([ts: 1, channel: 'channel_id'])
    end

    it 'warns if the bot leaves the channel' do
      expect {
        expect_any_instance_of(Logger).to receive(:warn).with(/not_in_channel/)
        expect(user.team.slack_client).to receive(:chat_postMessage) {
          raise Slack::Web::Api::Errors::SlackError, 'not_in_channel'
        }
        expect(activity.brag!).to eq []
      }.not_to change(User, :count)
    end

    it 'warns if the account goes inactive' do
      expect {
        expect {
          expect_any_instance_of(Logger).to receive(:warn).with(/account_inactive/)
          expect(user.team.slack_client).to receive(:chat_postMessage) {
            raise Slack::Web::Api::Errors::SlackError, 'account_inactive'
          }
          expect(activity.brag!).to eq []
        }.not_to change(User, :count)
      }.not_to change(UserActivity, :count)
    end

    it 'informs user on restricted_action' do
      expect {
        expect(user).to receive(:dm!).with(text: "I wasn't allowed to post into <#channel_id> because of a Slack workspace preference, please contact your Slack admin.")
        expect_any_instance_of(Logger).to receive(:warn).with(/restricted_action/)
        expect(user.team.slack_client).to receive(:chat_postMessage) {
          raise Slack::Web::Api::Errors::SlackError, 'restricted_action'
        }
        expect(activity.brag!).to eq []
      }.not_to change(User, :count)
    end
  end

  context 'unbrag!' do
    let(:team) { Fabricate(:team) }
    let(:user) { Fabricate(:user, team: team) }
    let!(:activity) { Fabricate(:user_activity, user: user) }

    before do
      activity.update_attributes!(
        bragged_at: Time.now.utc,
        channel_messages: [
          ChannelMessage.new(channel: 'channel1', ts: 'ts'),
          ChannelMessage.new(channel: 'channel2', ts: 'ts')
        ]
      )
    end

    it 'deletes message' do
      expect(activity.user.team.slack_client).to receive(:chat_delete).with(
        channel: 'channel1',
        ts: 'ts',
        as_user: true
      )
      expect(activity.user.team.slack_client).to receive(:chat_delete).with(
        channel: 'channel2',
        ts: 'ts',
        as_user: true
      )
      activity.unbrag!
      expect(activity.reload.channel_messages).to eq []
    end
  end

  context 'miles' do
    let(:team) { Fabricate(:team, units: 'mi') }
    let(:user) { Fabricate(:user, team: team) }
    let(:activity) { Fabricate(:user_activity, user: user) }

    it 'to_slack' do
      expect(activity.to_slack).to eq(
        attachments: [
          {
            fallback: "#{activity.name} via #{activity.user.slack_mention} 14.01mi 2h6m26s 9m02s/mi",
            title: activity.name,
            title_link: "https://www.strava.com/activities/#{activity.strava_id}",
            text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM\n\nGreat run!",
            image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png",
            fields: [
              { title: 'Type', value: 'Run 🏃', short: true },
              { title: 'Distance', value: '14.01mi', short: true },
              { title: 'Moving Time', value: '2h6m26s', short: true },
              { title: 'Elapsed Time', value: '2h8m6s', short: true },
              { title: 'Pace', value: '9m02s/mi', short: true },
              { title: 'Speed', value: '6.6mph', short: true },
              { title: 'Elevation', value: '475.4ft', short: true },
              { title: 'Weather', value: '70°F Rain', short: true }
            ],
            author_name: user.athlete.name,
            author_link: user.athlete.strava_url,
            author_icon: user.athlete.profile_medium
          }
        ]
      )
    end

    context 'with all fields' do
      before do
        team.activity_fields = ['All']
      end

      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [
            {
              fallback: "#{activity.name} via #{activity.user.slack_mention} 14.01mi 2h6m26s 9m02s/mi",
              title: activity.name,
              title_link: "https://www.strava.com/activities/#{activity.strava_id}",
              text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM\n\nGreat run!",
              image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png",
              fields: [
                { title: 'Type', value: 'Run 🏃', short: true },
                { title: 'Distance', value: '14.01mi', short: true },
                { title: 'Moving Time', value: '2h6m26s', short: true },
                { title: 'Elapsed Time', value: '2h8m6s', short: true },
                { title: 'Pace', value: '9m02s/mi', short: true },
                { title: 'Speed', value: '6.6mph', short: true },
                { title: 'Elevation', value: '475.4ft', short: true },
                { title: 'Max Speed', value: '20.8mph', short: true },
                { title: 'Heart Rate', value: '140.3bpm', short: true },
                { title: 'Max Heart Rate', value: '178.0bpm', short: true },
                { title: 'PR Count', value: '3', short: true },
                { title: 'Calories', value: '870.2', short: true },
                { title: 'Weather', value: '70°F Rain', short: true }
              ],
              author_name: user.athlete.name,
              author_link: user.athlete.strava_url,
              author_icon: user.athlete.profile_medium
            }
          ]
        )
      end
    end

    context 'with none fields' do
      before do
        team.activity_fields = ['None']
      end

      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [
            {
              fallback: "#{activity.name} via #{activity.user.slack_mention}",
              title: activity.name,
              title_link: "https://www.strava.com/activities/#{activity.strava_id}",
              text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM\n\nGreat run!",
              image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png",
              author_name: user.athlete.name,
              author_link: user.athlete.strava_url,
              author_icon: user.athlete.profile_medium
            }
          ]
        )
      end
    end

    context 'with all header fields' do
      before do
        team.activity_fields = %w[Title Url User Description Date Athlete]
      end

      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [
            {
              fallback: "#{activity.name} via #{activity.user.slack_mention}",
              title: activity.name,
              title_link: "https://www.strava.com/activities/#{activity.strava_id}",
              text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM\n\nGreat run!",
              image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png",
              author_name: user.athlete.name,
              author_link: user.athlete.strava_url,
              author_icon: user.athlete.profile_medium
            }
          ]
        )
      end
    end

    context 'without athlete' do
      before do
        team.activity_fields = %w[Title Url User Description Date]
      end

      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [
            {
              fallback: "#{activity.name} via #{activity.user.slack_mention}",
              title: activity.name,
              title_link: "https://www.strava.com/activities/#{activity.strava_id}",
              text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM\n\nGreat run!",
              image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png"
            }
          ]
        )
      end
    end

    context 'without user' do
      before do
        team.activity_fields = %w[Title Url Description Date]
      end

      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [
            {
              fallback: activity.name,
              title: activity.name,
              title_link: "https://www.strava.com/activities/#{activity.strava_id}",
              text: "Tuesday, February 20, 2018 at 10:02 AM\n\nGreat run!",
              image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png"
            }
          ]
        )
      end
    end

    context 'without description' do
      before do
        team.activity_fields = %w[Title Url User Date]
      end

      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [
            {
              fallback: "#{activity.name} via #{activity.user.slack_mention}",
              title: activity.name,
              title_link: "https://www.strava.com/activities/#{activity.strava_id}",
              text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM",
              image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png"
            }
          ]
        )
      end
    end

    context 'without date' do
      before do
        team.activity_fields = %w[Title Url Description]
      end

      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [
            {
              fallback: activity.name,
              title: activity.name,
              title_link: "https://www.strava.com/activities/#{activity.strava_id}",
              text: 'Great run!',
              image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png"
            }
          ]
        )
      end
    end

    context 'without url' do
      before do
        team.activity_fields = %w[Title]
      end

      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [
            {
              fallback: activity.name,
              title: activity.name,
              image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png"
            }
          ]
        )
      end
    end

    context 'without title' do
      before do
        team.activity_fields = %w[Url]
      end

      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [
            {
              fallback: activity.strava_id,
              title: activity.strava_id,
              title_link: "https://www.strava.com/activities/#{activity.strava_id}",
              image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png"
            }
          ]
        )
      end
    end

    context 'without an athlete' do
      before do
        user.athlete.destroy
      end

      it 'to_slack' do
        expect(activity.reload.to_slack).to eq(
          attachments: [
            {
              fallback: "#{activity.name} via #{activity.user.slack_mention} 14.01mi 2h6m26s 9m02s/mi",
              title: activity.name,
              title_link: "https://www.strava.com/activities/#{activity.strava_id}",
              text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM\n\nGreat run!",
              image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png",
              fields: [
                { title: 'Type', value: 'Run 🏃', short: true },
                { title: 'Distance', value: '14.01mi', short: true },
                { title: 'Moving Time', value: '2h6m26s', short: true },
                { title: 'Elapsed Time', value: '2h8m6s', short: true },
                { title: 'Pace', value: '9m02s/mi', short: true },
                { title: 'Speed', value: '6.6mph', short: true },
                { title: 'Elevation', value: '475.4ft', short: true },
                { title: 'Weather', value: '70°F Rain', short: true }
              ]
            }
          ]
        )
      end
    end

    context 'with a zero speed' do
      before do
        activity.update_attributes!(average_speed: 0.0)
      end

      it 'to_slack' do
        expect(activity.reload.to_slack).to eq(
          attachments: [
            {
              fallback: "#{activity.name} via #{activity.user.slack_mention} 14.01mi 2h6m26s",
              title: activity.name,
              title_link: "https://www.strava.com/activities/#{activity.strava_id}",
              text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM\n\nGreat run!",
              image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png",
              fields: [
                { title: 'Type', value: 'Run 🏃', short: true },
                { title: 'Distance', value: '14.01mi', short: true },
                { title: 'Moving Time', value: '2h6m26s', short: true },
                { title: 'Elapsed Time', value: '2h8m6s', short: true },
                { title: 'Elevation', value: '475.4ft', short: true },
                { title: 'Weather', value: '70°F Rain', short: true }
              ],
              author_name: user.athlete.name,
              author_link: user.athlete.strava_url,
              author_icon: user.athlete.profile_medium
            }
          ]
        )
      end
    end
  end

  context 'km' do
    let(:team) { Fabricate(:team, units: 'km') }
    let(:user) { Fabricate(:user, team: team) }
    let(:activity) { Fabricate(:user_activity, user: user) }

    it 'to_slack' do
      expect(activity.to_slack).to eq(
        attachments: [
          {
            fallback: "#{activity.name} via #{activity.user.slack_mention} 22.54km 2h6m26s 5m37s/km",
            title: activity.name,
            title_link: "https://www.strava.com/activities/#{activity.strava_id}",
            text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM\n\nGreat run!",
            image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png",
            fields: [
              { title: 'Type', value: 'Run 🏃', short: true },
              { title: 'Distance', value: '22.54km', short: true },
              { title: 'Moving Time', value: '2h6m26s', short: true },
              { title: 'Elapsed Time', value: '2h8m6s', short: true },
              { title: 'Pace', value: '5m37s/km', short: true },
              { title: 'Speed', value: '10.7km/h', short: true },
              { title: 'Elevation', value: '144.9m', short: true },
              { title: 'Weather', value: '21°C Rain', short: true }
            ],
            author_name: user.athlete.name,
            author_link: user.athlete.strava_url,
            author_icon: user.athlete.profile_medium
          }
        ]
      )
    end
  end

  context 'both' do
    let(:team) { Fabricate(:team, units: 'both') }
    let(:user) { Fabricate(:user, team: team) }
    let(:activity) { Fabricate(:user_activity, user: user) }

    it 'to_slack' do
      expect(activity.to_slack).to eq(
        attachments: [
          {
            fallback: "#{activity.name} via #{activity.user.slack_mention} 14.01mi 22.54km 2h6m26s 9m02s/mi 5m37s/km",
            title: activity.name,
            title_link: "https://www.strava.com/activities/#{activity.strava_id}",
            text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM\n\nGreat run!",
            image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png",
            fields: [
              { title: 'Type', value: 'Run 🏃', short: true },
              { title: 'Distance', value: '14.01mi 22.54km', short: true },
              { title: 'Moving Time', value: '2h6m26s', short: true },
              { title: 'Elapsed Time', value: '2h8m6s', short: true },
              { title: 'Pace', value: '9m02s/mi 5m37s/km', short: true },
              { title: 'Speed', value: '6.6mph 10.7km/h', short: true },
              { title: 'Elevation', value: '475.4ft 144.9m', short: true },
              { title: 'Weather', value: '70°F 21°C Rain', short: true }
            ],
            author_name: user.athlete.name,
            author_link: user.athlete.strava_url,
            author_icon: user.athlete.profile_medium
          }
        ]
      )
    end
  end

  context 'swim activity in yards' do
    let(:team) { Fabricate(:team) }
    let(:user) { Fabricate(:user, team: team) }
    let(:activity) { Fabricate(:swim_activity, user: user) }

    it 'to_slack' do
      expect(activity.to_slack).to eq(
        attachments: [
          {
            fallback: "#{activity.name} via #{activity.user.slack_mention} 2050yd 37m 1m48s/100yd",
            title: activity.name,
            title_link: "https://www.strava.com/activities/#{activity.strava_id}",
            text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM",
            fields: [
              { title: 'Type', value: 'Swim 🏊', short: true },
              { title: 'Distance', value: '2050yd', short: true },
              { title: 'Time', value: '37m', short: true },
              { title: 'Pace', value: '1m48s/100yd', short: true },
              { title: 'Speed', value: '1.9mph', short: true }
            ],
            author_name: user.athlete.name,
            author_link: user.athlete.strava_url,
            author_icon: user.athlete.profile_medium
          }
        ]
      )
    end
  end

  context 'swim activity in meters' do
    let(:team) { Fabricate(:team, units: 'km') }
    let(:user) { Fabricate(:user, team: team) }
    let(:activity) { Fabricate(:swim_activity, user: user) }

    it 'to_slack' do
      expect(activity.to_slack).to eq(
        attachments: [
          {
            fallback: "#{activity.name} via #{activity.user.slack_mention} 1874m 37m 1m58s/100m",
            title: activity.name,
            title_link: "https://www.strava.com/activities/#{activity.strava_id}",
            text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM",
            fields: [
              { title: 'Type', value: 'Swim 🏊', short: true },
              { title: 'Distance', value: '1874m', short: true },
              { title: 'Time', value: '37m', short: true },
              { title: 'Pace', value: '1m58s/100m', short: true },
              { title: 'Speed', value: '3.0km/h', short: true }
            ],
            author_name: user.athlete.name,
            author_link: user.athlete.strava_url,
            author_icon: user.athlete.profile_medium
          }
        ]
      )
    end
  end

  context 'swim activity in both' do
    let(:team) { Fabricate(:team, units: 'both') }
    let(:user) { Fabricate(:user, team: team) }
    let(:activity) { Fabricate(:swim_activity, user: user) }

    it 'to_slack' do
      expect(activity.to_slack).to eq(
        attachments: [
          {
            fallback: "#{activity.name} via #{activity.user.slack_mention} 2050yd 1874m 37m 1m48s/100yd 1m58s/100m",
            title: activity.name,
            title_link: "https://www.strava.com/activities/#{activity.strava_id}",
            text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM",
            fields: [
              { title: 'Type', value: 'Swim 🏊', short: true },
              { title: 'Distance', value: '2050yd 1874m', short: true },
              { title: 'Time', value: '37m', short: true },
              { title: 'Pace', value: '1m48s/100yd 1m58s/100m', short: true },
              { title: 'Speed', value: '1.9mph 3.0km/h', short: true }
            ],
            author_name: user.athlete.name,
            author_link: user.athlete.strava_url,
            author_icon: user.athlete.profile_medium
          }
        ]
      )
    end
  end

  context 'ride activities in kilometers/hour' do
    let(:team) { Fabricate(:team, units: 'km') }
    let(:user) { Fabricate(:user, team: team) }
    let(:activity) { Fabricate(:ride_activity, user: user) }

    it 'to_slack' do
      expect(activity.to_slack).to eq(
        attachments: [
          {
            fallback: "#{activity.name} via #{activity.user.slack_mention} 28.1km 1h10m7s 2m30s/km",
            title: activity.name,
            title_link: "https://www.strava.com/activities/#{activity.strava_id}",
            text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM",
            fields: [
              { title: 'Type', value: 'Ride 🚴', short: true },
              { title: 'Distance', value: '28.1km', short: true },
              { title: 'Moving Time', value: '1h10m7s', short: true },
              { title: 'Elapsed Time', value: '1h13m30s', short: true },
              { title: 'Pace', value: '2m30s/km', short: true },
              { title: 'Speed', value: '24.0km/h', short: true }
            ],
            author_name: user.athlete.name,
            author_link: user.athlete.strava_url,
            author_icon: user.athlete.profile_medium
          }
        ]
      )
    end
  end

  context 'ride activities in both' do
    let(:team) { Fabricate(:team, units: 'both') }
    let(:user) { Fabricate(:user, team: team) }
    let(:activity) { Fabricate(:ride_activity, user: user) }

    it 'to_slack' do
      expect(activity.to_slack).to eq(
        attachments: [
          {
            fallback: "#{activity.name} via #{activity.user.slack_mention} 17.46mi 28.1km 1h10m7s 4m01s/mi 2m30s/km",
            title: activity.name,
            title_link: "https://www.strava.com/activities/#{activity.strava_id}",
            text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM",
            fields: [
              { title: 'Type', value: 'Ride 🚴', short: true },
              { title: 'Distance', value: '17.46mi 28.1km', short: true },
              { title: 'Moving Time', value: '1h10m7s', short: true },
              { title: 'Elapsed Time', value: '1h13m30s', short: true },
              { title: 'Pace', value: '4m01s/mi 2m30s/km', short: true },
              { title: 'Speed', value: '14.9mph 24.0km/h', short: true }
            ],
            author_name: user.athlete.name,
            author_link: user.athlete.strava_url,
            author_icon: user.athlete.profile_medium
          }
        ]
      )
    end
  end

  context 'map' do
    context 'with a summary polyline' do
      let(:activity) { Fabricate(:user_activity) }

      it 'start_latlng' do
        expect(activity.start_latlng).to eq([37.82822, -122.26348])
      end
    end

    context 'with a blank summary polyline' do
      let(:map) { Fabricate.build(:map, summary_polyline: '') }
      let(:activity) { Fabricate(:user_activity, map: map) }

      it 'start_latlng' do
        expect(activity.start_latlng).to be_nil
      end
    end
  end

  context 'maps' do
    context 'without maps' do
      let(:team) { Fabricate(:team, maps: 'off') }
      let(:user) { Fabricate(:user, team: team) }
      let(:activity) { Fabricate(:user_activity, user: user) }
      let(:attachment) { activity.to_slack[:attachments].first }

      it 'to_slack' do
        expect(attachment.keys).not_to include :image_url
        expect(attachment.keys).not_to include :thumb_url
      end
    end

    context 'with thumbnail' do
      let(:team) { Fabricate(:team, maps: 'thumb') }
      let(:user) { Fabricate(:user, team: team) }
      let(:activity) { Fabricate(:user_activity, user: user) }
      let(:attachment) { activity.to_slack[:attachments].first }

      it 'to_slack' do
        expect(attachment.keys).not_to include :image_url
        expect(attachment[:thumb_url]).to eq "https://slava.playplay.io/api/maps/#{activity.map.id}.png"
      end
    end
  end

  describe 'create_from_strava!' do
    let(:user) { Fabricate(:user) }
    let(:detailed_activity) do
      Strava::Models::Activity.new(
        JSON.parse(
          File.read(
            File.join(__dir__, '../fabricators/activity.json')
          )
        )
      )
    end

    it 'creates an activity' do
      expect {
        UserActivity.create_from_strava!(user, detailed_activity)
      }.to change(UserActivity, :count).by(1)
    end

    context 'with another existing activity' do
      let!(:activity) { Fabricate(:user_activity, user: user) }

      it 'creates another activity' do
        expect {
          UserActivity.create_from_strava!(user, detailed_activity)
        }.to change(UserActivity, :count).by(1)
        expect(user.reload.activities.count).to eq 2
      end
    end

    context 'with an existing activity' do
      let!(:activity) { UserActivity.create_from_strava!(user, detailed_activity) }

      it 'does not create another activity' do
        expect {
          UserActivity.create_from_strava!(user, detailed_activity)
        }.not_to change(UserActivity, :count)
      end

      it 'does not cause a save without changes' do
        expect_any_instance_of(UserActivity).not_to receive(:save!)
        UserActivity.create_from_strava!(user, detailed_activity)
      end

      it 'updates an existing activity' do
        activity.update_attributes!(name: 'Original')
        UserActivity.create_from_strava!(user, detailed_activity)
        expect(activity.reload.name).to eq 'First Time Breaking 14'
      end

      context 'concurrently' do
        before do
          expect(UserActivity).to receive(:where).with(
            strava_id: detailed_activity.id, team_id: user.team.id, user_id: user.id
          ).and_return([])
          allow(UserActivity).to receive(:where).and_call_original
        end

        it 'does not create a duplicate activity' do
          expect {
            expect {
              UserActivity.create_from_strava!(user, detailed_activity)
            }.to raise_error(Mongo::Error::OperationFailure)
          }.not_to change(UserActivity, :count)
        end
      end
    end
  end
end
