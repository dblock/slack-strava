require 'spec_helper'

describe ClubActivity do
  context 'miles' do
    let(:team) { Fabricate(:team, units: 'mi') }
    let(:club) { Fabricate(:club, team: team) }
    let(:activity) { Fabricate(:club_activity, club: club) }
    it 'to_slack' do
      expect(activity.to_slack).to eq(
        attachments: [
          {
            fallback: "#{activity.name} by #{activity.athlete_name} via #{club.name}, 14.01mi 2h6m26s 9m02s/mi",
            title: activity.name,
            title_link: club.strava_url,
            text: "#{activity.athlete_name}, #{club.name}",
            fields: [
              { title: 'Type', value: 'Run 🏃', short: true },
              { title: 'Distance', value: '14.01mi', short: true },
              { title: 'Moving Time', value: '2h6m26s', short: true },
              { title: 'Elapsed Time', value: '2h8m6s', short: true },
              { title: 'Pace', value: '9m02s/mi', short: true },
              { title: 'Elevation', value: '475.4ft', short: true }
            ],
            thumb_url: club.logo
          }
        ]
      )
    end
  end
  context 'km' do
    let(:team) { Fabricate(:team, units: 'km') }
    let(:club) { Fabricate(:club, team: team) }
    let(:activity) { Fabricate(:club_activity, club: club) }
    it 'to_slack' do
      expect(activity.to_slack).to eq(
        attachments: [
          {
            fallback: "#{activity.name} by #{activity.athlete_name} via #{club.name}, 22.54km 2h6m26s 5m37s/km",
            title: activity.name,
            title_link: club.strava_url,
            text: "#{activity.athlete_name}, #{club.name}",
            fields: [
              { title: 'Type', value: 'Run 🏃', short: true },
              { title: 'Distance', value: '22.54km', short: true },
              { title: 'Moving Time', value: '2h6m26s', short: true },
              { title: 'Elapsed Time', value: '2h8m6s', short: true },
              { title: 'Pace', value: '5m37s/km', short: true },
              { title: 'Elevation', value: '144.9m', short: true }
            ],
            thumb_url: club.logo
          }
        ]
      )
    end
  end
end
