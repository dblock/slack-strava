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
      }.to_not change(User, :count)
    end
    it 'warns if the account goes inactive' do
      expect {
        expect {
          expect_any_instance_of(Logger).to receive(:warn).with(/account_inactive/)
          expect(user.team.slack_client).to receive(:chat_postMessage) {
            raise Slack::Web::Api::Errors::SlackError, 'account_inactive'
          }
          expect(activity.brag!).to eq []
        }.to_not change(User, :count)
      }.to_not change(UserActivity, :count)
    end
    it 'informs user on restricted_action' do
      expect {
        expect(user).to receive(:dm!).with(text: "I wasn't allowed to post into <#channel_id> because of a Slack workspace preference, please contact your Slack admin.")
        expect_any_instance_of(Logger).to receive(:warn).with(/restricted_action/)
        expect(user.team.slack_client).to receive(:chat_postMessage) {
          raise Slack::Web::Api::Errors::SlackError, 'restricted_action'
        }
        expect(activity.brag!).to eq []
      }.to_not change(User, :count)
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
            fallback: "#{activity.name} via #{activity.user.slack_mention}, 14.01mi 2h6m26s 9m02s/mi",
            title: activity.name,
            title_link: "https://www.strava.com/activities/#{activity.strava_id}",
            text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM",
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
              fallback: "#{activity.name} via #{activity.user.slack_mention}, 14.01mi 2h6m26s 9m02s/mi",
              title: activity.name,
              title_link: "https://www.strava.com/activities/#{activity.strava_id}",
              text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM",
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
    context 'without an athlete' do
      before do
        user.athlete.destroy
      end
      it 'to_slack' do
        expect(activity.reload.to_slack).to eq(
          attachments: [
            {
              fallback: "#{activity.name} via #{activity.user.slack_mention}, 14.01mi 2h6m26s 9m02s/mi",
              title: activity.name,
              title_link: "https://www.strava.com/activities/#{activity.strava_id}",
              text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM",
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
              fallback: "#{activity.name} via #{activity.user.slack_mention}, 14.01mi 2h6m26s",
              title: activity.name,
              title_link: "https://www.strava.com/activities/#{activity.strava_id}",
              text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM",
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
            fallback: "#{activity.name} via #{activity.user.slack_mention}, 22.54km 2h6m26s 5m37s/km",
            title: activity.name,
            title_link: "https://www.strava.com/activities/#{activity.strava_id}",
            text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM",
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
            fallback: "#{activity.name} via #{activity.user.slack_mention}, 14.01mi 22.54km 2h6m26s 9m02s/mi 5m37s/km",
            title: activity.name,
            title_link: "https://www.strava.com/activities/#{activity.strava_id}",
            text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM",
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
            fallback: "#{activity.name} via #{activity.user.slack_mention}, 2050yd 37m 1m48s/100yd",
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
            fallback: "#{activity.name} via #{activity.user.slack_mention}, 1874m 37m 1m58s/100m",
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
            fallback: "#{activity.name} via #{activity.user.slack_mention}, 2050yd 1874m 37m 1m48s/100yd 1m58s/100m",
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
            fallback: "#{activity.name} via #{activity.user.slack_mention}, 28.1km 1h10m7s 2m30s/km",
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
            fallback: "#{activity.name} via #{activity.user.slack_mention}, 17.46mi 28.1km 1h10m7s 4m01s/mi 2m30s/km",
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
        expect(activity.start_latlng).to be nil
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
        expect(attachment.keys).to_not include :image_url
        expect(attachment.keys).to_not include :thumb_url
      end
    end
    context 'with thumbnail' do
      let(:team) { Fabricate(:team, maps: 'thumb') }
      let(:user) { Fabricate(:user, team: team) }
      let(:activity) { Fabricate(:user_activity, user: user) }
      let(:attachment) { activity.to_slack[:attachments].first }
      it 'to_slack' do
        expect(attachment.keys).to_not include :image_url
        expect(attachment[:thumb_url]).to eq "https://slava.playplay.io/api/maps/#{activity.map.id}.png"
      end
    end
  end
end
