require 'spec_helper'

describe Activity do
  context 'miles' do
    let(:team) { Fabricate(:team, units: 'mi') }
    let(:user) { Fabricate(:user, team: team) }
    let(:activity) { Fabricate(:activity, user: user) }
    it 'to_slack' do
      expect(activity.to_slack).to eq(
        attachments: [
          {
            fallback: "#{activity.name} via #{activity.user.slack_mention}, 14.01mi 2h06m26s 9m02s/mi",
            title: "#{activity.name} via <@#{activity.user.user_name}>",
            title_link: "https://www.strava.com/activities/#{activity.strava_id}",
            image_url: "https://strava.playplay.io/api/maps/#{activity.map.id}.png",
            fields: [
              { title: 'Distance', value: '14.01mi', short: true },
              { title: 'Time', value: '2h06m26s', short: true },
              { title: 'Pace', value: '9m02s/mi', short: true }
            ]
          }
        ]
      )
    end
  end
  context 'km' do
    let(:team) { Fabricate(:team, units: 'km') }
    let(:user) { Fabricate(:user, team: team) }
    let(:activity) { Fabricate(:activity, user: user) }
    it 'to_slack' do
      expect(activity.to_slack).to eq(
        attachments: [
          {
            fallback: "#{activity.name} via #{activity.user.slack_mention}, 22.54km 2h06m26s 5m37s/km",
            title: "#{activity.name} via <@#{activity.user.user_name}>",
            title_link: "https://www.strava.com/activities/#{activity.strava_id}",
            image_url: "https://strava.playplay.io/api/maps/#{activity.map.id}.png",
            fields: [
              { title: 'Distance', value: '22.54km', short: true },
              { title: 'Time', value: '2h06m26s', short: true },
              { title: 'Pace', value: '5m37s/km', short: true }
            ]
          }
        ]
      )
    end
  end
end
