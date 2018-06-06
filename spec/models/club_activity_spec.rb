require 'spec_helper'

describe ClubActivity do
  context 'brag!' do
    let(:team) { Fabricate(:team) }
    let(:club) { Fabricate(:club, team: team) }
    let!(:activity) { Fabricate(:club_activity, club: club) }
    it 'sends a message to the subscribed channel' do
      expect(club.team.slack_client).to receive(:chat_postMessage).with(
        activity.to_slack.merge(
          channel: club.channel_id,
          as_user: true
        )
      ).and_return('ts' => 1)
      expect(activity.brag!).to eq(ts: 1, channel: club.channel_id)
    end
    it 'destroys the activity if the bot left the channel' do
      expect {
        expect {
          expect(club.team.slack_client).to receive(:chat_postMessage) {
            raise Slack::Web::Api::Errors::SlackError, 'not_in_channel'
          }
          expect(activity.brag!).to be nil
        }.to change(Club, :count).by(-1)
      }.to change(ClubActivity, :count).by(-1)
    end
  end
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
              { title: 'Speed', value: '6.6mph', short: true },
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
              { title: 'Speed', value: '10.7km/h', short: true },
              { title: 'Elevation', value: '144.9m', short: true }
            ],
            thumb_url: club.logo
          }
        ]
      )
    end
  end
  context 'fields' do
    let(:club) { Fabricate(:club, team: team) }
    let(:activity) { Fabricate(:club_activity, club: club) }
    context 'none' do
      let(:team) { Fabricate(:team, activity_fields: ['None']) }
      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [
            {
              fallback: "#{activity.name} by #{activity.athlete_name} via #{club.name}, 14.01mi 2h6m26s 9m02s/mi",
              title: activity.name,
              title_link: club.strava_url,
              text: "#{activity.athlete_name}, #{club.name}",
              thumb_url: club.logo
            }
          ]
        )
      end
    end
    context 'some' do
      let(:team) { Fabricate(:team, activity_fields: %w[Pace Elevation Type]) }
      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [
            {
              fallback: "#{activity.name} by #{activity.athlete_name} via #{club.name}, 14.01mi 2h6m26s 9m02s/mi",
              title: activity.name,
              title_link: club.strava_url,
              text: "#{activity.athlete_name}, #{club.name}",
              fields: [
                { title: 'Pace', value: '9m02s/mi', short: true },
                { title: 'Elevation', value: '475.4ft', short: true },
                { title: 'Type', value: 'Run 🏃', short: true }
              ],
              thumb_url: club.logo
            }
          ]
        )
      end
    end
  end
end
