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
      expect(activity.brag!).to eq([ts: 1, channel: club.channel_id])
    end
    it 'warns if the bot leaves the channel' do
      expect {
        expect_any_instance_of(Logger).to receive(:warn).with(/not_in_channel/)
        expect(club.team.slack_client).to receive(:chat_postMessage) {
          raise Slack::Web::Api::Errors::SlackError, 'not_in_channel'
        }
        expect(activity.brag!).to be nil
      }.to_not change(Club, :count)
    end
    it 'warns if the account goes inactive' do
      expect {
        expect {
          expect_any_instance_of(Logger).to receive(:warn).with(/account_inactive/)
          expect(club.team.slack_client).to receive(:chat_postMessage) {
            raise Slack::Web::Api::Errors::SlackError, 'account_inactive'
          }
          expect(activity.brag!).to be nil
        }.to_not change(Club, :count)
      }.to_not change(ClubActivity, :count)
    end
    it 'informs admin on restricted_action' do
      expect {
        expect_any_instance_of(Logger).to receive(:warn).with(/restricted_action/)
        expect(club.team).to receive(:inform_admin!).with(text: "I wasn't allowed to post into <##{club.channel_id}> because of a Slack workspace preference, please contact your Slack admin.")
        expect(club.team.slack_client).to receive(:chat_postMessage) {
          raise Slack::Web::Api::Errors::SlackError, 'restricted_action'
        }
        expect(activity.brag!).to be nil
      }.to_not change(Club, :count)
    end
    context 'having already bragged a user activity in the channel' do
      let!(:user_activity) do
        Fabricate(:user_activity,
                  team: club.team,
                  distance: activity.distance,
                  moving_time: activity.moving_time,
                  elapsed_time: activity.elapsed_time,
                  total_elevation_gain: activity.total_elevation_gain,
                  map: nil,
                  bragged_at: Time.now.utc,
                  channel_messages: [
                    ChannelMessage.new(channel: club.channel_id)
                  ])
      end
      it 'does not re-brag the activity' do
        expect(club.team.slack_client).to_not receive(:chat_postMessage)
        expect {
          expect(activity.brag!).to be nil
        }.to change(club.activities.unbragged, :count).by(-1)
        expect(activity.bragged_at).to_not be_nil
      end
    end
    context 'having a private user activity' do
      let!(:user_activity) do
        Fabricate(:user_activity,
                  team: club.team,
                  distance: activity.distance,
                  moving_time: activity.moving_time,
                  elapsed_time: activity.elapsed_time,
                  total_elevation_gain: activity.total_elevation_gain,
                  map: nil,
                  private: true)
      end
      context 'unbragged' do
        it 'rebrags the activity' do
          expect(club.team.slack_client).to receive(:chat_postMessage).with(
            activity.to_slack.merge(
              channel: club.channel_id,
              as_user: true
            )
          ).and_return('ts' => 1)
          expect(activity.brag!).to eq([ts: 1, channel: club.channel_id])
        end
      end
      context 'bragged recently' do
        before do
          user_activity.set(bragged_at: Time.now.utc)
        end
        it 'does not rebrag the activity' do
          expect(club.team.slack_client).to_not receive(:chat_postMessage)
          expect {
            expect(activity.brag!).to be nil
          }.to change(club.activities.unbragged, :count).by(-1)
          expect(activity.bragged_at).to_not be_nil
        end
      end
      context 'bragged a long time ago' do
        before do
          user_activity.set(bragged_at: Time.now.utc - 1.month)
        end
        it 'rebrags the activity' do
          expect(club.team.slack_client).to receive(:chat_postMessage).with(
            activity.to_slack.merge(
              channel: club.channel_id,
              as_user: true
            )
          ).and_return('ts' => 1)
          expect(activity.brag!).to eq([ts: 1, channel: club.channel_id])
        end
      end
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
