require 'spec_helper'

describe ClubActivity do
  context 'hidden?' do
    context 'default' do
      let(:activity) { Fabricate(:club_activity) }

      it 'is not hidden' do
        expect(activity.hidden?).to be false
      end
    end
  end

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

    %i[daily weekly monthly].each do |threads|
      context "with #{threads} threads" do
        before do
          team.update_attributes!(threads: threads)
        end

        context 'with a parent from today' do
          let!(:thread_parent) do
            Fabricate(
              :club_activity,
              club: club,
              distance: 123,
              bragged_at: Time.now.utc,
              channel_messages: [
                ChannelMessage.new(ts: 'ts', channel: club.channel_id)
              ]
            )
          end

          it 'threads the activity under a previous one' do
            expect(club.team.slack_client).to receive(:chat_postMessage).with(
              activity.to_slack.merge(
                channel: club.channel_id,
                as_user: true,
                thread_ts: 'ts'
              )
            ).and_return('ts' => 1)
            expect(activity.brag!).to eq([ts: 1, channel: club.channel_id])
          end
        end

        context 'with a parent from over a month ago' do
          let!(:thread_parent) do
            Fabricate(
              :club_activity,
              club: club,
              distance: 123,
              bragged_at: Time.now.utc - 1.month - 1.day,
              channel_messages: [
                ChannelMessage.new(ts: 'ts', channel: club.channel_id)
              ]
            )
          end

          it 'does not thread the activity under a previous one' do
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

    it 'warns if the bot leaves the channel' do
      expect {
        expect_any_instance_of(Logger).to receive(:warn).with(/not_in_channel/)
        expect(club.team.slack_client).to receive(:chat_postMessage) {
          raise Slack::Web::Api::Errors::SlackError, 'not_in_channel'
        }
        expect(activity.brag!).to be_nil
      }.not_to change(Club, :count)
      expect(club.reload.sync_activities).to be false
    end

    it 'warns if the account goes inactive' do
      expect {
        expect {
          expect_any_instance_of(Logger).to receive(:warn).with(/account_inactive/)
          expect(club.team.slack_client).to receive(:chat_postMessage) {
            raise Slack::Web::Api::Errors::SlackError, 'account_inactive'
          }
          expect(activity.brag!).to be_nil
        }.not_to change(Club, :count)
      }.not_to change(described_class, :count)
      expect(club.reload.sync_activities).to be false
    end

    it 'informs admin on restricted_action' do
      expect {
        expect_any_instance_of(Logger).to receive(:warn).with(/restricted_action/)
        expect(club.team).to receive(:inform_admin!).with(text: "I wasn't allowed to post into <##{club.channel_id}> because of a Slack workspace preference, please contact your Slack admin.")
        expect(club.team.slack_client).to receive(:chat_postMessage) {
          raise Slack::Web::Api::Errors::SlackError, 'restricted_action'
        }
        expect(activity.brag!).to be_nil
      }.not_to change(Club, :count)
      expect(club.reload.sync_activities).to be false
    end

    it 'informs admin on is_archived channel' do
      expect {
        expect_any_instance_of(Logger).to receive(:warn).with(/is_archived/)
        expect(club.team).to receive(:inform_admin!).with(text: "I couldn't post an activity from #{club.name} into <##{club.channel_id}> because the channel was archived, please reconnect that club in a different channel.")
        expect(club.team.slack_client).to receive(:chat_postMessage) {
          raise Slack::Web::Api::Errors::SlackError, 'is_archived'
        }
        expect(activity.brag!).to be_nil
      }.not_to change(Club, :count)
      expect(club.reload.sync_activities).to be false
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
        expect(club.team.slack_client).not_to receive(:chat_postMessage)
        expect {
          expect(activity.brag!).to be_nil
        }.to change(club.activities.unbragged, :count).by(-1)
        expect(activity.bragged_at).not_to be_nil
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
          expect(club.team.slack_client).not_to receive(:chat_postMessage)
          expect {
            expect(activity.brag!).to be_nil
          }.to change(club.activities.unbragged, :count).by(-1)
          expect(activity.bragged_at).not_to be_nil
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
        attachments: [],
        blocks: [
          { type: 'section', text: { type: 'mrkdwn', text: "*<#{club.strava_url}|#{activity.name}>*" } },
          { type: 'context', elements: [{ type: 'mrkdwn', text: "#{activity.athlete_name} via #{club.name}" }] },
          {
            type: 'section',
            accessory: { type: 'image', alt_text: club.name, image_url: club.logo },
            text: {
              type: 'mrkdwn',
              text: [
                { title: 'Type', value: 'Run 🏃' },
                { title: 'Distance', value: '14.01mi' },
                { title: 'Moving Time', value: '2h6m26s' },
                { title: 'Elapsed Time', value: '2h8m6s' },
                { title: 'Pace', value: '9m02s/mi' },
                { title: 'Speed', value: '6.6mph' },
                { title: 'Elevation', value: '475.4ft' }
              ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
            }
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
        attachments: [],
        blocks: [
          { type: 'section', text: { type: 'mrkdwn', text: "*<#{club.strava_url}|#{activity.name}>*" } },
          { type: 'context', elements: [{ type: 'mrkdwn', text: "#{activity.athlete_name} via #{club.name}" }] },
          {
            type: 'section',
            accessory: { type: 'image', alt_text: club.name, image_url: club.logo },
            text: {
              type: 'mrkdwn',
              text: [
                { title: 'Type', value: 'Run 🏃' },
                { title: 'Distance', value: '22.54km' },
                { title: 'Moving Time', value: '2h6m26s' },
                { title: 'Elapsed Time', value: '2h8m6s' },
                { title: 'Pace', value: '5m37s/km' },
                { title: 'Speed', value: '10.7km/h' },
                { title: 'Elevation', value: '144.9m' }
              ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
            }
          }
        ]
      )
    end
  end

  context 'both' do
    let(:team) { Fabricate(:team, units: 'both') }
    let(:club) { Fabricate(:club, team: team) }
    let(:activity) { Fabricate(:club_activity, club: club) }

    it 'to_slack' do
      expect(activity.to_slack).to eq(
        attachments: [],
        blocks: [
          { type: 'section', text: { type: 'mrkdwn', text: "*<#{club.strava_url}|#{activity.name}>*" } },
          { type: 'context', elements: [{ type: 'mrkdwn', text: "#{activity.athlete_name} via #{club.name}" }] },
          {
            type: 'section',
            accessory: { type: 'image', alt_text: club.name, image_url: club.logo },
            text: {
              type: 'mrkdwn',
              text: [
                { title: 'Type', value: 'Run 🏃' },
                { title: 'Distance', value: '14.01mi 22.54km' },
                { title: 'Moving Time', value: '2h6m26s' },
                { title: 'Elapsed Time', value: '2h8m6s' },
                { title: 'Pace', value: '9m02s/mi 5m37s/km' },
                { title: 'Speed', value: '6.6mph 10.7km/h' },
                { title: 'Elevation', value: '475.4ft 144.9m' }
              ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
            }
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
          attachments: [],
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: "*<#{club.strava_url}|#{activity.name}>*" } },
            { type: 'context', elements: [{ type: 'mrkdwn', text: "#{activity.athlete_name} via #{club.name}" }] }
          ]
        )
      end
    end

    context 'some' do
      let(:team) { Fabricate(:team, activity_fields: %w[Pace Elevation Type]) }

      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [],
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: "*<#{club.strava_url}|#{activity.name}>*" } },
            { type: 'context', elements: [{ type: 'mrkdwn', text: "#{activity.athlete_name} via #{club.name}" }] },
            {
              type: 'section',
              accessory: { type: 'image', alt_text: club.name, image_url: club.logo },
              text: {
                type: 'mrkdwn',
                text: [
                  { title: 'Pace', value: '9m02s/mi' },
                  { title: 'Elevation', value: '475.4ft' },
                  { title: 'Type', value: 'Run 🏃' }
                ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
              }
            }
          ]
        )
      end
    end
  end
end
