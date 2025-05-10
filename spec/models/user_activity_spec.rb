require 'spec_helper'

describe UserActivity do
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

    context 'a user in a channel' do
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

      %i[daily weekly monthly].each do |threads|
        context "with #{threads} threads" do
          before do
            team.update_attributes!(threads: threads)
          end

          context 'with a parent from today' do
            let!(:thread_parent) do
              Fabricate(
                :user_activity,
                user: user,
                bragged_at: Time.now.utc,
                channel_messages: [
                  ChannelMessage.new(ts: 'ts', channel: 'channel_id')
                ]
              )
            end

            it 'returns the correct parent' do
              expect(activity.parent_thread('channel_id')).to eq 'ts'
            end

            it 'threads the activity under a previous one' do
              expect(user.team.slack_client).to receive(:chat_postMessage).with(
                activity.to_slack.merge(
                  as_user: true,
                  channel: 'channel_id',
                  thread_ts: 'ts'
                )
              ).and_return('ts' => 1)
              expect(activity.brag!).to eq([ts: 1, channel: 'channel_id'])
            end
          end

          context 'with a parent posted to multiple channels' do
            let!(:thread_parent) do
              Fabricate(
                :user_activity,
                user: user,
                bragged_at: Time.now.utc,
                channel_messages: [
                  ChannelMessage.new(ts: 'ts1', channel: 'channel_1'),
                  ChannelMessage.new(ts: 'ts2', channel: 'channel_2')
                ]
              )
            end

            it 'returns the correct parent' do
              expect(activity.parent_thread('channel_1')).to eq 'ts1'
              expect(activity.parent_thread('channel_2')).to eq 'ts2'
              expect(activity.parent_thread('another_channel')).to be_nil
            end
          end

          context 'with a parent outside of the range' do
            let!(:thread_parent) do
              Fabricate(
                :user_activity,
                start_date_local: Time.new(2015, 1, 1),
                user: user,
                channel_messages: [
                  ChannelMessage.new(ts: 'ts', channel: 'channel_id')
                ]
              )
            end

            it 'does not thread the activity under a previous one' do
              expect(user.team.slack_client).to receive(:chat_postMessage).with(
                activity.to_slack.merge(
                  as_user: true,
                  channel: 'channel_id'
                )
              ).and_return('ts' => 1)
              expect(activity.brag!).to eq([ts: 1, channel: 'channel_id'])
            end
          end
        end
      end
    end

    context 'a deleted user' do
      before do
        allow_any_instance_of(Team).to receive(:slack_channels).and_return(['id' => 'channel_id'])
        allow_any_instance_of(User).to receive(:user_deleted?).and_return(true)
      end

      it 'does not send messages' do
        expect(user.team.slack_client).not_to receive(:chat_postMessage)
        expect(activity.brag!).to eq([])
      end
    end
  end

  describe '#display_title_s' do
    it 'displays the title with a link' do
      activity = Fabricate(:user_activity, name: 'Test Activity', strava_id: '123')
      allow(activity).to receive(:display_field?).and_return(true)
      expect(activity.display_title_s).to eq('*<https://www.strava.com/activities/123|Test Activity>*')
    end

    it 'falls back on title with ID link with emojis' do
      activity = Fabricate(:user_activity, name: 'Survived 🐕 💥', strava_id: '123')
      allow(activity).to receive(:display_field?).and_return(true)
      expect(activity.display_title_s).to eq('*Survived 🐕 💥* <https://www.strava.com/activities/123|…>')
    end

    it 'displays the title only' do
      activity = Fabricate(:user_activity, name: 'Test Activity', strava_id: '123')
      allow(activity).to receive(:display_field?).with(ActivityFields::URL).and_return(false)
      allow(activity).to receive(:display_field?).with(ActivityFields::TITLE).and_return(true)
      expect(activity.display_title_s).to eq('*Test Activity*')
    end

    it 'displays the URL with ID only' do
      activity = Fabricate(:user_activity, name: 'Test Activity', strava_id: '123')
      allow(activity).to receive(:display_field?).with(ActivityFields::URL).and_return(true)
      allow(activity).to receive(:display_field?).with(ActivityFields::TITLE).and_return(false)
      expect(activity.display_title_s).to eq('*<https://www.strava.com/activities/123|123>*')
    end

    it 'displays neither' do
      activity = Fabricate(:user_activity, name: 'Test Activity', strava_id: '123')
      allow(activity).to receive(:display_field?).with(ActivityFields::URL).and_return(false)
      allow(activity).to receive(:display_field?).with(ActivityFields::TITLE).and_return(false)
      expect(activity.display_title_s).to be_nil
    end
  end

  describe '#display_athlete_s' do
    it 'displays first and last names with link' do
      user = Fabricate(:user, athlete: Fabricate.build(:athlete, username: 'username', firstname: 'First', lastname: 'Last'))
      activity = Fabricate(:user_activity, user: user)
      allow(activity).to receive(:display_field?).and_return(true)
      expect(activity.display_athlete_s).to eq('<https://www.strava.com/athletes/username|First Last>')
    end

    it 'falls back with name containing an emoji' do
      user = Fabricate(:user, athlete: Fabricate.build(:athlete, username: 'username', firstname: '💥', lastname: '🐕'))
      activity = Fabricate(:user_activity, user: user)
      allow(activity).to receive(:display_field?).and_return(true)
      expect(activity.display_athlete_s).to eq('💥 🐕 <https://www.strava.com/athletes/username|…>')
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
        {
          channel: 'channel1',
          ts: 'ts',
          as_user: true
        }
      )
      expect(activity.user.team.slack_client).to receive(:chat_delete).with(
        {
          channel: 'channel2',
          ts: 'ts',
          as_user: true
        }
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
        attachments: [],
        blocks: [
          { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
          {
            type: 'context',
            elements: [
              { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
              { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥇 on Tuesday, February 20, 2018 at 10:02 AM" }
            ]
          },
          { type: 'section', text: { type: 'plain_text', text: activity.description, emoji: true } },
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: [
                { title: 'Type', value: 'Run 🏃' },
                { title: 'Distance', value: '14.01mi' },
                { title: 'Moving Time', value: '2h6m26s' },
                { title: 'Elapsed Time', value: '2h8m6s' },
                { title: 'Pace', value: '9m02s/mi' },
                { title: 'Speed', value: '6.6mph' },
                { title: 'Elevation', value: '475.4ft' },
                { title: 'Weather', value: '70°F Rain' }
              ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
            }
          },
          { type: 'image', image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png", alt_text: '' }
        ]
      )
    end

    context 'with all fields' do
      before do
        team.activity_fields = ['All']
      end

      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [],
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
            {
              type: 'context',
              elements: [
                { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
                { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥇 on Tuesday, February 20, 2018 at 10:02 AM" }
              ]
            },
            { type: 'section', text: { type: 'plain_text', text: activity.description, emoji: true } },
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: [
                  { title: 'Type', value: 'Run 🏃' },
                  { title: 'Distance', value: '14.01mi' },
                  { title: 'Moving Time', value: '2h6m26s' },
                  { title: 'Elapsed Time', value: '2h8m6s' },
                  { title: 'Pace', value: '9m02s/mi' },
                  { title: 'Speed', value: '6.6mph' },
                  { title: 'Elevation', value: '475.4ft' },
                  { title: 'Max Speed', value: '20.8mph' },
                  { title: 'Heart Rate', value: '140.3bpm' },
                  { title: 'Max Heart Rate', value: '178.0bpm' },
                  { title: 'PR Count', value: '3' },
                  { title: 'Calories', value: '870.2' },
                  { title: 'Weather', value: '70°F Rain' }
                ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
              }
            },
            { type: 'image', image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png", alt_text: '' }
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
          attachments: [],
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
            {
              type: 'context',
              elements: [
                { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
                { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥇 on Tuesday, February 20, 2018 at 10:02 AM" }
              ]
            },
            { type: 'section', text: { type: 'plain_text', text: activity.description, emoji: true } },
            { type: 'image', image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png", alt_text: '' }
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
          attachments: [],
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
            {
              type: 'context',
              elements: [
                { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
                { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM" }
              ]
            },
            { type: 'section', text: { type: 'plain_text', text: activity.description, emoji: true } },
            { type: 'image', image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png", alt_text: '' }
          ]
        )
      end
    end

    context 'with all header fields and medal' do
      before do
        team.activity_fields = %w[Title Url User Medal Description Date Athlete]
      end

      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [],
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
            {
              type: 'context',
              elements: [
                { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
                { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥇 on Tuesday, February 20, 2018 at 10:02 AM" }
              ]
            },
            { type: 'section', text: { type: 'plain_text', text: activity.description, emoji: true } },
            { type: 'image', image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png", alt_text: '' }
          ]
        )
      end
    end

    context 'ranked second' do
      before do
        team.activity_fields = %w[Title Url User Medal Description Date Athlete]
        Fabricate(:user_activity, user: Fabricate(:user, team: team), distance: activity.distance + 1)
      end

      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [],
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
            {
              type: 'context',
              elements: [
                { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
                { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥈 on Tuesday, February 20, 2018 at 10:02 AM" }
              ]
            },
            { type: 'section', text: { type: 'plain_text', text: activity.description, emoji: true } },
            { type: 'image', image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png", alt_text: '' }
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
          attachments: [],
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
            {
              type: 'context',
              elements: [
                { type: 'mrkdwn', text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM" }
              ]
            },
            { type: 'section', text: { type: 'plain_text', text: activity.description, emoji: true } },
            { type: 'image', image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png", alt_text: '' }
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
          attachments: [],
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
            {
              type: 'context',
              elements: [
                { type: 'mrkdwn', text: 'Tuesday, February 20, 2018 at 10:02 AM' }
              ]
            },
            { type: 'section', text: { type: 'plain_text', text: activity.description, emoji: true } },
            { type: 'image', image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png", alt_text: '' }
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
          attachments: [],
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
            {
              type: 'context',
              elements: [
                { type: 'mrkdwn', text: "<@#{activity.user.user_name}> on Tuesday, February 20, 2018 at 10:02 AM" }
              ]
            },
            { type: 'image', image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png", alt_text: '' }
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
          attachments: [],
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
            { type: 'section', text: { type: 'plain_text', text: activity.description, emoji: true } },
            { type: 'image', image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png", alt_text: '' }
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
          attachments: [],
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: "*#{activity.name}*" } },
            { type: 'image', image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png", alt_text: '' }
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
          attachments: [],
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.strava_id}>*" } },
            { type: 'image', image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png", alt_text: '' }
          ]
        )
      end
    end

    context 'without an athlete' do
      before do
        user.athlete.destroy
      end

      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [],
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
            {
              type: 'context',
              elements: [
                { type: 'mrkdwn', text: "<@#{activity.user.user_name}> 🥇 on Tuesday, February 20, 2018 at 10:02 AM" }
              ]
            },
            { type: 'section', text: { type: 'plain_text', text: activity.description, emoji: true } },
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: [
                  { title: 'Type', value: 'Run 🏃' },
                  { title: 'Distance', value: '14.01mi' },
                  { title: 'Moving Time', value: '2h6m26s' },
                  { title: 'Elapsed Time', value: '2h8m6s' },
                  { title: 'Pace', value: '9m02s/mi' },
                  { title: 'Speed', value: '6.6mph' },
                  { title: 'Elevation', value: '475.4ft' },
                  { title: 'Weather', value: '70°F Rain' }
                ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
              }
            },
            { type: 'image', image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png", alt_text: '' }
          ]
        )
      end
    end

    context 'with a zero speed' do
      before do
        activity.update_attributes!(average_speed: 0.0)
      end

      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [],
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
            {
              type: 'context',
              elements: [
                { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
                { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥇 on Tuesday, February 20, 2018 at 10:02 AM" }
              ]
            },
            { type: 'section', text: { type: 'plain_text', text: activity.description, emoji: true } },
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: [
                  { title: 'Type', value: 'Run 🏃' },
                  { title: 'Distance', value: '14.01mi' },
                  { title: 'Moving Time', value: '2h6m26s' },
                  { title: 'Elapsed Time', value: '2h8m6s' },
                  { title: 'Elevation', value: '475.4ft' },
                  { title: 'Weather', value: '70°F Rain' }
                ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
              }
            },
            { type: 'image', image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png", alt_text: '' }
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
        attachments: [],
        blocks: [
          { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
          {
            type: 'context',
            elements: [
              { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
              { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥇 on Tuesday, February 20, 2018 at 10:02 AM" }
            ]
          },
          { type: 'section', text: { type: 'plain_text', text: activity.description, emoji: true } },
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: [
                { title: 'Type', value: 'Run 🏃' },
                { title: 'Distance', value: '22.54km' },
                { title: 'Moving Time', value: '2h6m26s' },
                { title: 'Elapsed Time', value: '2h8m6s' },
                { title: 'Pace', value: '5m37s/km' },
                { title: 'Speed', value: '10.7km/h' },
                { title: 'Elevation', value: '144.9m' },
                { title: 'Weather', value: '21°C Rain' }
              ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
            }
          },
          { type: 'image', image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png", alt_text: '' }
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
        attachments: [],
        blocks: [
          { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
          {
            type: 'context',
            elements: [
              { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
              { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥇 on Tuesday, February 20, 2018 at 10:02 AM" }
            ]
          },
          { type: 'section', text: { type: 'plain_text', text: activity.description, emoji: true } },
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: [
                { title: 'Type', value: 'Run 🏃' },
                { title: 'Distance', value: '14.01mi 22.54km' },
                { title: 'Moving Time', value: '2h6m26s' },
                { title: 'Elapsed Time', value: '2h8m6s' },
                { title: 'Pace', value: '9m02s/mi 5m37s/km' },
                { title: 'Speed', value: '6.6mph 10.7km/h' },
                { title: 'Elevation', value: '475.4ft 144.9m' },
                { title: 'Weather', value: '70°F 21°C Rain' }
              ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
            }
          },
          { type: 'image', image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png", alt_text: '' }
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
        attachments: [],
        blocks: [
          { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
          {
            type: 'context',
            elements: [
              { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
              { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥇 on Tuesday, February 20, 2018 at 10:02 AM" }
            ]
          },
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: [
                { title: 'Type', value: 'Swim 🏊' },
                { title: 'Distance', value: '2050yd' },
                { title: 'Time', value: '37m' },
                { title: 'Pace', value: '1m48s/100yd' },
                { title: 'Speed', value: '1.9mph' }
              ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
            }
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
        attachments: [],
        blocks: [
          { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
          {
            type: 'context',
            elements: [
              { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
              { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥇 on Tuesday, February 20, 2018 at 10:02 AM" }
            ]
          },
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: [
                { title: 'Type', value: 'Swim 🏊' },
                { title: 'Distance', value: '1874m' },
                { title: 'Time', value: '37m' },
                { title: 'Pace', value: '1m58s/100m' },
                { title: 'Speed', value: '3.0km/h' }
              ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
            }
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
        attachments: [],
        blocks: [
          { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
          {
            type: 'context',
            elements: [
              { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
              { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥇 on Tuesday, February 20, 2018 at 10:02 AM" }
            ]
          },
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: [
                { title: 'Type', value: 'Swim 🏊' },
                { title: 'Distance', value: '2050yd 1874m' },
                { title: 'Time', value: '37m' },
                { title: 'Pace', value: '1m48s/100yd 1m58s/100m' },
                { title: 'Speed', value: '1.9mph 3.0km/h' }
              ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
            }
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
        attachments: [],
        blocks: [
          { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
          {
            type: 'context',
            elements: [
              { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
              { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥇 on Tuesday, February 20, 2018 at 10:02 AM" }
            ]
          },
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: [
                { title: 'Type', value: 'Ride 🚴' },
                { title: 'Distance', value: '28.1km' },
                { title: 'Moving Time', value: '1h10m7s' },
                { title: 'Elapsed Time', value: '1h13m30s' },
                { title: 'Pace', value: '2m30s/km' },
                { title: 'Speed', value: '24.0km/h' }
              ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
            }
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
        attachments: [],
        blocks: [
          { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
          {
            type: 'context',
            elements: [
              { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
              { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥇 on Tuesday, February 20, 2018 at 10:02 AM" }
            ]
          },
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: [
                { title: 'Type', value: 'Ride 🚴' },
                { title: 'Distance', value: '17.46mi 28.1km' },
                { title: 'Moving Time', value: '1h10m7s' },
                { title: 'Elapsed Time', value: '1h13m30s' },
                { title: 'Pace', value: '4m01s/mi 2m30s/km' },
                { title: 'Speed', value: '14.9mph 24.0km/h' }
              ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
            }
          }
        ]
      )
    end
  end

  context 'alpine ski activity' do
    let(:team) { Fabricate(:team) }
    let(:user) { Fabricate(:user, team: team) }
    let(:activity) { Fabricate(:alpine_ski_activity, user: user) }

    it 'to_slack' do
      expect(activity.to_slack).to eq(
        attachments: [],
        blocks: [
          { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
          {
            type: 'context',
            elements: [
              { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
              { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥇 on Wednesday, January 29, 2025 at 09:07 AM" }
            ]
          },
          {
            type: 'section',
            text: {
              type: 'mrkdwn',
              text: [
                { title: 'Type', value: 'Alpine Ski ⛷️' },
                { title: 'Distance', value: '14.35mi' },
                { title: 'Moving Time', value: '1h15m54s' },
                { title: 'Elapsed Time', value: '5h40m27s' }
              ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
            }
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
    context 'with an empty polyline' do
      let(:team) { Fabricate(:team, maps: 'thumb') }
      let(:user) { Fabricate(:user, team:) }
      let(:activity) { Fabricate(:user_activity, user:, map: { summary_polyline: '' }) }
      let(:embed) { activity.to_discord[:embeds].first }

      it 'does not insert an empty point to the decoded polyline' do
        expect(activity.map.decoded_summary_polyline).to be_nil
      end

      it 'does not have a polyline' do
        expect(activity.map.polyline?).to be false
        expect(activity.map.image_url).to be_nil
        expect(activity.map.proxy_image_url).to be_nil
      end
    end

    context 'without maps' do
      let(:team) { Fabricate(:team, maps: 'off') }
      let(:user) { Fabricate(:user, team: team) }
      let(:activity) { Fabricate(:user_activity, user: user) }

      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [],
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
            {
              type: 'context',
              elements: [
                { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
                { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥇 on Tuesday, February 20, 2018 at 10:02 AM" }
              ]
            },
            { text: { emoji: true, text: 'Great run!', type: 'plain_text' }, type: 'section' },
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: [
                  { title: 'Type', value: 'Run 🏃' },
                  { title: 'Distance', value: '14.01mi' },
                  { title: 'Moving Time', value: '2h6m26s' },
                  { title: 'Elapsed Time', value: '2h8m6s' },
                  { title: 'Pace', value: '9m02s/mi' },
                  { title: 'Speed', value: '6.6mph' },
                  { title: 'Elevation', value: '475.4ft' },
                  { title: 'Weather', value: '70°F Rain' }
                ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
              }
            }
          ]
        )
      end
    end

    context 'with thumbnail' do
      let(:team) { Fabricate(:team, maps: 'thumb') }
      let(:user) { Fabricate(:user, team: team) }
      let(:activity) { Fabricate(:user_activity, user: user) }

      it 'to_slack' do
        expect(activity.to_slack).to eq(
          attachments: [],
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: "*<https://www.strava.com/activities/#{activity.strava_id}|#{activity.name}>*" } },
            {
              type: 'context',
              elements: [
                { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
                { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥇 on Tuesday, February 20, 2018 at 10:02 AM" }
              ]
            },
            { text: { emoji: true, text: 'Great run!', type: 'plain_text' }, type: 'section' },
            {
              type: 'section',
              text: {
                type: 'mrkdwn',
                text: [
                  { title: 'Type', value: 'Run 🏃' },
                  { title: 'Distance', value: '14.01mi' },
                  { title: 'Moving Time', value: '2h6m26s' },
                  { title: 'Elapsed Time', value: '2h8m6s' },
                  { title: 'Pace', value: '9m02s/mi' },
                  { title: 'Speed', value: '6.6mph' },
                  { title: 'Elevation', value: '475.4ft' },
                  { title: 'Weather', value: '70°F Rain' }
                ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
              },
              accessory: {
                alt_text: '',
                type: 'image',
                image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png"
              }
            }
          ]
        )
      end
    end
  end

  describe 'create_from_strava!' do
    let(:user) { Fabricate(:user) }

    context 'a detailed activity' do
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

      context 'created activity' do
        let(:activity) { UserActivity.create_from_strava!(user, detailed_activity) }
        let(:formatted_time) { 'Wednesday, March 28, 2018 at 07:51 PM' }

        it 'has the correct time zone data' do
          expect(detailed_activity.start_date_local.strftime('%A, %B %d, %Y at %I:%M %p')).to eq formatted_time
          expect(detailed_activity.start_date_local.utc_offset).to eq(-14_400)
        end

        it 'stores the correct time zone' do
          expect(activity.start_date_local_in_local_time.utc_offset).to eq(-14_400)
          expect(activity.start_date_local_s).to eq formatted_time
        end

        it 'preserves the correct time zone across reloads' do
          expect(activity.reload.start_date_local_s).to eq formatted_time
          expect(activity.start_date_local_in_local_time.utc_offset).to eq(-14_400)
        end
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

    context 'a ride' do
      let(:detailed_activity) do
        Strava::Models::Activity.new(
          JSON.parse(
            File.read(
              File.join(__dir__, '../fabricators/ride_activity.json')
            )
          )
        )
      end

      context 'a new activity' do
        let(:activity) { UserActivity.create_from_strava!(user, detailed_activity) }

        it 'has the correct type' do
          expect(activity.type).to eq 'Ride'
        end

        it 'has a photo' do
          expect(activity.photos.count).to eq(1)
          expect(activity.photos.first.to_slack).to eq(
            alt_text: '',
            image_url: 'https://dgtzuqphqg23d.cloudfront.net/Bv93zv5t_mr57v0wXFbY_JyvtucgmU5Ym6N9z_bKeUI-128x96.jpg',
            type: 'image'
          )
        end

        it 'to_slack' do
          expect(activity.to_slack).to eq(
            attachments: [],
            blocks: [
              { type: 'section', text: { type: 'mrkdwn', text: '*<https://www.strava.com/activities/1493471377|Evening Ride>*' } },
              {
                type: 'context',
                elements: [
                  { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
                  { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥇 on Friday, February 16, 2018 at 06:52 AM" }
                ]
              },
              {
                type: 'section',
                text: {
                  type: 'mrkdwn',
                  text: [
                    { title: 'Type', value: 'Ride 🚴' },
                    { title: 'Distance', value: '17.46mi' },
                    { title: 'Moving Time', value: '1h10m7s' },
                    { title: 'Elapsed Time', value: '1h13m30s' },
                    { title: 'Pace', value: '4m01s/mi' },
                    { title: 'Speed', value: '14.9mph' },
                    { title: 'Elevation', value: '1692.9ft' }
                  ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
                }
              },
              {
                type: 'image',
                alt_text: '',
                image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png"
              },
              {
                type: 'image',
                alt_text: '',
                image_url: 'https://dgtzuqphqg23d.cloudfront.net/Bv93zv5t_mr57v0wXFbY_JyvtucgmU5Ym6N9z_bKeUI-128x96.jpg'
              }
            ]
          )
        end
      end

      context 'an existing activity' do
        let!(:activity) do
          Fabricate(
            :ride_activity,
            strava_id: detailed_activity.id,
            user: user,
            photos: [
              Photo.new(
                unique_id: 'uuid',
                urls: {
                  '100' => '100.jpg'
                }
              )
            ]
          )
        end

        before do
          expect {
            UserActivity.create_from_strava!(user, detailed_activity)
          }.not_to change(UserActivity, :count)

          activity.reload
        end

        it 'has the correct type' do
          expect(activity.type).to eq 'Ride'
        end

        it 'to_slack' do
          expect(activity.to_slack).to eq(
            attachments: [],
            blocks: [
              { type: 'section', text: { type: 'mrkdwn', text: '*<https://www.strava.com/activities/1493471377|Evening Ride>*' } },
              {
                type: 'context',
                elements: [
                  { type: 'image', image_url: user.athlete.profile_medium, alt_text: user.athlete.name },
                  { type: 'mrkdwn', text: "<#{user.athlete.strava_url}|#{user.athlete.name}> <@#{activity.user.user_name}> 🥇 on Friday, February 16, 2018 at 06:52 AM" }
                ]
              },
              {
                type: 'section',
                text: {
                  type: 'mrkdwn',
                  text: [
                    { title: 'Type', value: 'Ride 🚴' },
                    { title: 'Distance', value: '17.46mi' },
                    { title: 'Moving Time', value: '1h10m7s' },
                    { title: 'Elapsed Time', value: '1h13m30s' },
                    { title: 'Pace', value: '4m01s/mi' },
                    { title: 'Speed', value: '14.9mph' },
                    { title: 'Elevation', value: '1692.9ft' }
                  ].map { |f| "*#{f[:title]}*: #{f[:value]}" }.join("\n")
                }
              },
              {
                type: 'image',
                alt_text: '',
                image_url: "https://slava.playplay.io/api/maps/#{activity.map.id}.png"
              },
              {
                type: 'image',
                alt_text: '',
                image_url: 'https://dgtzuqphqg23d.cloudfront.net/Bv93zv5t_mr57v0wXFbY_JyvtucgmU5Ym6N9z_bKeUI-128x96.jpg'
              }
            ]
          )
        end
      end
    end
  end
end
