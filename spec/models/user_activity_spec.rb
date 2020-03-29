require 'spec_helper'

describe UserActivity do
  before do
    allow(HTTParty).to receive_message_chain(:get, :body).and_return('PNG')
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
              { title: 'Elevation', value: '475.4ft', short: true }
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
                { title: 'Calories', value: '870.2', short: true }
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
                { title: 'Elevation', value: '475.4ft', short: true }
              ]
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
              { title: 'Elevation', value: '144.9m', short: true }
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
