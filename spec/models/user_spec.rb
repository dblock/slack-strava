require 'spec_helper'

describe User do
  before do
    allow_any_instance_of(Map).to receive(:update_png!)
  end

  describe '#find_by_slack_mention!' do
    let!(:user) { Fabricate(:user) }

    it 'finds by slack id' do
      expect(User.find_by_slack_mention!(user.team, "<@#{user.user_id}>")).to eq user
    end

    it 'finds by username' do
      expect(User.find_by_slack_mention!(user.team, user.user_name)).to eq user
    end

    it 'finds by username is case-insensitive' do
      expect(User.find_by_slack_mention!(user.team, user.user_name.capitalize)).to eq user
    end

    it 'requires a known user' do
      expect {
        User.find_by_slack_mention!(user.team, '<@nobody>')
      }.to raise_error SlackStrava::Error, "I don't know who <@nobody> is!"
    end
  end

  describe '#find_create_or_update_by_slack_id!', vcr: { cassette_name: 'slack/user_info' } do
    let!(:team) { Fabricate(:team) }
    let(:client) { SlackRubyBot::Client.new }

    before do
      client.owner = team
    end

    context 'with a mismatching user id in slack_mention' do
      let!(:user) { Fabricate(:user, team: team) }
      let(:web_client) { double(Slack::Web::Client, users_info: { user: { id: user.user_id, name: user.user_name } }) }

      before do
        allow(client).to receive(:web_client).and_return(web_client)
      end

      it 'finds by different slack id returned from slack info' do
        expect(User.find_create_or_update_by_slack_id!(client, 'unknown')).to eq user
      end
    end

    context 'without a user' do
      it 'creates a user' do
        expect {
          user = User.find_create_or_update_by_slack_id!(client, 'whatever')
          expect(user).not_to be_nil
          expect(user.user_id).to eq 'U007'
          expect(user.user_name).to eq 'username'
          expect(user.is_admin).to be true
          expect(user.is_bot).to be false
          expect(user.is_owner).to be true
        }.to change(User, :count).by(1)
      end
    end

    context 'with a user with info matching an existing user id' do
      let!(:user) { Fabricate(:user, team: team, is_admin: true, user_id: 'U007') }

      it 'updates the fields of the existing user' do
        expect {
          User.find_create_or_update_by_slack_id!(client, 'whatever')
        }.not_to change(User, :count)
        user.reload
        expect(user.user_id).to eq 'U007'
        expect(user.is_admin).to be true
        expect(user.is_bot).to be false
        expect(user.is_owner).to be true
      end
    end

    context 'with a user' do
      let!(:user) { Fabricate(:user, team: team) }

      it 'creates another user' do
        expect {
          User.find_create_or_update_by_slack_id!(client, 'whatever')
        }.to change(User, :count).by(1)
      end

      it 'updates the username of the existing user' do
        expect {
          User.find_create_or_update_by_slack_id!(client, user.user_id)
        }.not_to change(User, :count)
        expect(user.reload.user_name).to eq 'username'
      end
    end

    context 'with a user that matches most fields coming from slack' do
      let!(:user) { Fabricate(:user, team: team, is_admin: true, user_name: 'username') }

      it 'updates the fields of the existing user' do
        expect {
          User.find_create_or_update_by_slack_id!(client, user.user_id)
        }.not_to change(User, :count)
        user.reload
        expect(user.user_name).to eq 'username'
        expect(user.is_admin).to be true
        expect(user.is_bot).to be false
        expect(user.is_owner).to be true
      end
    end
  end

  context 'sync_new_strava_activities!' do
    context 'recent created_at', vcr: { cassette_name: 'strava/user_sync_new_strava_activities', allow_playback_repeats: true } do
      let!(:user) { Fabricate(:user, created_at: DateTime.new(2018, 3, 26), access_token: 'token', token_expires_at: Time.now + 1.day, token_type: 'Bearer') }

      it 'retrieves new activities since created_at' do
        expect {
          user.sync_new_strava_activities!
        }.to change(user.activities, :count).by(3)
      end

      it 'logs and raises errors' do
        allow(UserActivity).to receive(:create_from_strava!) do |_user, _response|
          raise Strava::Errors::Fault.new(404, body: { 'message' => 'Not Found', 'errors' => [{ 'resource' => 'Activity', 'field' => 'id', 'code' => 'not_found' }] })
        end
        expect {
          user.sync_new_strava_activities!
        }.to raise_error(Strava::Errors::Fault)
      end

      it 'sets activities_at to nil without any bragged activity' do
        user.sync_new_strava_activities!
        expect(user.activities_at).to be_nil
      end

      context 'with unbragged activities' do
        let!(:activity) { Fabricate(:user_activity, user: user, start_date: DateTime.new(2018, 4, 1)) }

        it 'syncs activities since the first one' do
          expect(user).to receive(:sync_strava_activities!).with({ after: activity.start_date.to_i })
          user.sync_new_strava_activities!
        end
      end

      context 'with activities in user_sync_new_strava_activities.yml across more than 5 days' do
        let(:weather) { Fabricate(:one_call_weather) }
        let(:activities) do
          {
            march_26: { dt: Time.parse('2018-03-26T13:57:15Z'), lat: 40.73115, lon: -74.00686 },
            march_28: { dt: Time.parse('2018-03-29T01:59:40Z'), lat: 40.68294, lon: -73.9147 },
            april_04: { dt: Time.parse('2018-04-01T16:58:34Z'), lat: 40.78247, lon: -73.96003 }
          }
        end

        before do
          # end of first activity in user_sync_new_strava_activities.yml, with two more a few days ago
          Timecop.travel(activities[:april_04][:dt] + 4.hours)
        end

        after do
          Timecop.return
        end

        context 'with weather' do
          before do
            # april 04: recent under 9 hours
            allow_any_instance_of(OpenWeather::Client).to receive(:one_call).with(
              exclude: %w[minutely hourly daily], lat: activities[:april_04][:lat], lon: activities[:april_04][:lon]
            ).and_return(weather)
            # march 28, historical data within 5 days
            allow_any_instance_of(OpenWeather::Client).to receive(:one_call).with(
              activities[:march_28].merge(exclude: ['hourly'])
            ).and_return(weather)
            # march 26, more than 5 days old, too old
          end

          it 'fetches weather for all activities' do
            expect {
              user.sync_new_strava_activities!
            }.to change(user.activities, :count).by(3)
            expect(user.activities[0].weather).to be_nil
            expect(user.activities[1].weather).not_to be_nil
            expect(user.activities[1].weather.temp).to eq 294.31
            expect(user.activities[2].weather).not_to be_nil
            expect(user.activities[2].weather.temp).to eq 294.31
          end
        end

        context 'without weather' do
          before do
            weather = double(OpenWeather::Models::OneCall::Weather)
            allow(weather).to receive(:current).and_return(nil)
            allow_any_instance_of(OpenWeather::Client).to receive(:one_call).and_return(weather)
          end

          it 'does not fail' do
            expect {
              user.sync_new_strava_activities!
            }.to change(user.activities, :count).by(3)
            expect(user.activities[0].weather).to be_nil
            expect(user.activities[1].weather).to be_nil
            expect(user.activities[2].weather).to be_nil
          end
        end
      end

      context 'sync_and_brag!' do
        it 'syncs and brags' do
          expect_any_instance_of(User).to receive(:inform!)
          user.sync_and_brag!
        end

        it 'uses a lock' do
          user_instance_2 = User.find(user._id)
          bragged_activities = []
          allow_any_instance_of(User).to receive(:inform!) do |_, args|
            bragged_activities << args[:blocks][0][:text][:text]
            [{ ts: '1503425956.000247', channel: 'channel' }]
          end
          user.sync_and_brag!
          expect(user_instance_2).to receive(:sync_strava_activities!).with({ after: 1_522_072_635 })
          user_instance_2.sync_and_brag!
          expect(bragged_activities).to eq(
            [
              '*<https://www.strava.com/activities/1473024961|Restarting the Engine>*',
              '*<https://www.strava.com/activities/1477353766|First Time Breaking 14>*'
            ]
          )
        end

        it 'warns on error' do
          expect_any_instance_of(Logger).to receive(:warn).with(/unexpected error/)
          allow(user).to receive(:sync_new_strava_activities!).and_raise 'unexpected error'
          expect { user.sync_and_brag! }.not_to raise_error
        end

        context 'rate limit exceeded' do
          let(:rate_limit_exceeded_error) { Strava::Errors::Fault.new(429, body: { 'message' => 'Rate Limit Exceeded', 'errors' => [{ 'resource' => 'Application', 'field' => 'rate limit', 'code' => 'exceeded' }] }) }

          it 'raises an exception' do
            allow(user).to receive(:sync_new_strava_activities!).and_raise rate_limit_exceeded_error
            expect { user.sync_and_brag! }.to raise_error(Strava::Errors::Fault, /Rate Limit Exceeded/)
          end
        end

        context 'refresh token' do
          let(:authorization_error) { Strava::Errors::Fault.new(400, body: { 'message' => 'Bad Request', 'errors' => [{ 'resource' => 'RefreshToken', 'field' => 'refresh_token', 'code' => 'invalid' }] }) }

          it 'raises an exception and resets token' do
            allow(user.strava_client).to receive(:paginate).and_raise authorization_error
            expect(user).to receive(:dm_connect!).with('There was a re-authorization problem with Strava. Make sure that you leave the "View data about your private activities" box checked when reconnecting your Strava account')
            user.sync_and_brag!
            expect(user.access_token).to be_nil
            expect(user.token_type).to be_nil
            expect(user.refresh_token).to be_nil
            expect(user.token_expires_at).to be_nil
            expect(user.connected_to_strava_at).to be_nil
          end
        end

        context 'invalid token' do
          let(:authorization_error) { Strava::Errors::Fault.new(401, body: { 'message' => 'Authorization Error', 'errors' => [{ 'resource' => 'Athlete', 'field' => 'access_token', 'code' => 'invalid' }] }) }

          it 'raises an exception and resets token' do
            allow(user.strava_client).to receive(:paginate).and_raise authorization_error
            expect(user).to receive(:dm_connect!).with('There was an authorization problem with Strava. Make sure that you leave the "View data about your private activities" box checked when reconnecting your Strava account')
            user.sync_and_brag!
            expect(user.access_token).to be_nil
            expect(user.token_type).to be_nil
            expect(user.refresh_token).to be_nil
            expect(user.token_expires_at).to be_nil
            expect(user.connected_to_strava_at).to be_nil
          end
        end

        context 'read:permission authorization error' do
          let(:authorization_error) { Strava::Errors::Fault.new(401, body: { 'message' => 'Authorization Error', 'errors' => [{ 'resource' => 'AccessToken', 'field' => 'activity:read_permission', 'code' => 'missing' }] }) }

          it 'raises an exception and resets token' do
            allow(user.strava_client).to receive(:paginate).and_raise authorization_error
            expect(user).to receive(:dm_connect!).with('There was an authorization problem with Strava. Make sure that you leave the "View data about your private activities" box checked when reconnecting your Strava account')
            user.sync_and_brag!
            expect(user.access_token).to be_nil
            expect(user.token_type).to be_nil
            expect(user.refresh_token).to be_nil
            expect(user.token_expires_at).to be_nil
            expect(user.connected_to_strava_at).to be_nil
          end
        end
      end

      context 'with bragged activities' do
        before do
          user.sync_new_strava_activities!
          allow_any_instance_of(User).to receive(:inform!).and_return([{ ts: 'ts', channel: 'C1' }])
          user.brag!
        end

        it 'does not reset activities_at back if the most recent bragged activity is in the past' do
          expect(user.activities_at).not_to be_nil
          past = Time.parse('2012-01-01T12:34Z')
          Fabricate(:user_activity, user: user, start_date: past)
          user.brag!
          expect(user.activities_at).not_to eq past
        end

        it 'sets activities_at to the most recent bragged activity' do
          expect(user.activities_at).to eq user.activities.bragged.max(:start_date)
        end

        it 'updates activities since activities_at' do
          expect(user).to receive(:sync_strava_activities!).with({ after: user.activities_at.to_i })
          user.sync_new_strava_activities!
        end

        context 'latest activity' do
          let(:last_activity) { user.activities.bragged.desc(:_id).first }

          before do
            allow(user).to receive(:latest_bragged_activity).and_return(last_activity)
          end

          it 'retrieves last activity details and rebrags it with updated description' do
            updated_last_activity = last_activity.to_slack
            updated_last_activity[:blocks].insert(2, { type: 'section', text: { text: 'detailed description', type: 'plain_text', emoji: true } })
            expect_any_instance_of(User).to receive(:update!).with(
              updated_last_activity,
              last_activity.channel_messages
            )
            user.rebrag!
          end

          it 'does not rebrag if the activity has not changed' do
            expect_any_instance_of(User).to receive(:update!).once
            2.times { user.rebrag! }
          end
        end
      end

      context 'without a refresh token (until October 2019)', vcr: { cassette_name: 'strava/refresh_access_token' } do
        before do
          user.update_attributes!(refresh_token: nil, token_expires_at: nil)
        end

        it 'refreshes access token using access token' do
          user.send(:strava_client)
          expect(user.refresh_token).to eq 'updated-refresh-token'
          expect(user.access_token).to eq 'updated-access-token'
          expect(user.token_expires_at).not_to be_nil
          expect(user.token_type).to eq 'Bearer'
        end
      end

      context 'with an expired refresh token', vcr: { cassette_name: 'strava/refresh_access_token' } do
        before do
          user.update_attributes!(refresh_token: 'refresh_token', token_expires_at: nil)
        end

        it 'refreshes access token' do
          user.send(:strava_client)
          expect(user.refresh_token).to eq 'updated-refresh-token'
          expect(user.access_token).to eq 'updated-access-token'
          expect(user.token_expires_at).not_to be_nil
          expect(user.token_type).to eq 'Bearer'
        end
      end
    end

    context 'old created_at' do
      let!(:user) { Fabricate(:user, created_at: DateTime.new(2018, 2, 1), access_token: 'token', token_expires_at: Time.now + 1.day, token_type: 'Bearer') }

      it 'retrieves multiple pages of activities', vcr: { cassette_name: 'strava/user_sync_new_strava_activities_many' } do
        expect {
          user.sync_new_strava_activities!
        }.to change(user.activities, :count).by(14)
      end
    end

    context 'different connected_to_strava_at includes 8 hours of prior activities' do
      let!(:user) { Fabricate(:user, connected_to_strava_at: DateTime.new(2018, 2, 1) + 8.hours, access_token: 'token', token_expires_at: Time.now + 1.day, token_type: 'Bearer') }

      it 'retrieves multiple pages of activities', vcr: { cassette_name: 'strava/user_sync_new_strava_activities_many' } do
        expect {
          user.sync_new_strava_activities!
        }.to change(user.activities, :count).by(14)
      end
    end

    context 'with private activities', vcr: { cassette_name: 'strava/user_sync_new_strava_activities_with_private' } do
      let!(:user) { Fabricate(:user, created_at: DateTime.new(2018, 3, 26), access_token: 'token', token_expires_at: Time.now + 1.day, token_type: 'Bearer') }

      context 'by default' do
        it 'includes private activities' do
          expect {
            user.sync_new_strava_activities!
          }.to change(user.activities, :count).by(4)
          expect(user.activities.select(&:private).count).to eq 2
        end

        it 'does not brag private activities' do
          user.sync_new_strava_activities!
          allow_any_instance_of(UserActivity).to receive(:user).and_return(user)
          expect(user).to receive(:inform!).twice
          5.times { user.brag! }
        end
      end

      context 'with private_activities set to true' do
        before do
          user.update_attributes!(private_activities: true)
        end

        it 'brags private activities' do
          user.sync_new_strava_activities!
          allow_any_instance_of(UserActivity).to receive(:user).and_return(user)
          expect(user).to receive(:inform!).exactly(4).times
          5.times { user.brag! }
        end
      end
    end

    context 'with follower only activities', vcr: { cassette_name: 'strava/user_sync_new_strava_activities_privacy' } do
      let!(:user) { Fabricate(:user, created_at: DateTime.new(2018, 3, 26), access_token: 'token', token_expires_at: Time.now + 1.day, token_type: 'Bearer') }

      context 'by default' do
        it 'includes followers only activities' do
          expect {
            user.sync_new_strava_activities!
          }.to change(user.activities, :count).by(3)
          expect(user.activities.select(&:private).count).to eq 1
          expect(user.activities.map(&:visibility)).to eq %w[everyone only_me followers_only]
        end

        it 'brags follower only activities' do
          user.sync_new_strava_activities!
          allow_any_instance_of(UserActivity).to receive(:user).and_return(user)
          expect(user).to receive(:inform!).twice
          3.times { user.brag! }
        end
      end

      context 'with followers_only_activities set to false' do
        before do
          user.update_attributes!(followers_only_activities: false)
        end

        it 'does not brag follower only activities' do
          user.sync_new_strava_activities!
          allow_any_instance_of(UserActivity).to receive(:user).and_return(user)
          expect(user).to receive(:inform!).once
          3.times { user.brag! }
        end
      end

      context 'with private set to false' do
        before do
          user.update_attributes!(private_activities: false)
        end

        it 'brags follower only activities' do
          user.sync_new_strava_activities!
          allow_any_instance_of(UserActivity).to receive(:user).and_return(user)
          expect(user).to receive(:inform!).twice
          3.times { user.brag! }
        end
      end
    end

    context 'with sync_activities set to false' do
      let!(:user) { Fabricate(:user, connected_to_strava_at: DateTime.new(2018, 2, 1), access_token: 'token', token_expires_at: Time.now + 1.day, token_type: 'Bearer', sync_activities: false) }

      it 'does not retrieve any activities' do
        expect {
          user.sync_new_strava_activities!
        }.not_to change(user.activities, :count)
      end
    end
  end

  context 'brag!' do
    let!(:user) { Fabricate(:user) }

    it 'brags the last unbragged activity' do
      activity = Fabricate(:user_activity, user: user)
      expect_any_instance_of(UserActivity).to receive(:brag!).and_return(
        [
          ts: '1503425956.000247',
          channel: {
            id: 'C1',
            name: 'channel'
          }
        ]
      )
      results = user.brag!
      expect(results.size).to eq(1)
      expect(results.first[:ts]).to eq '1503425956.000247'
      expect(results.first[:channel]).to eq(id: 'C1', name: 'channel')
      expect(results.first[:activity]).to eq activity
    end
  end

  describe '#inform!' do
    let(:user) { Fabricate(:user, user_id: 'U0HLFUZLJ') }

    before do
      user.team.bot_user_id = 'bot_user_id'
    end

    it 'sends message to all channels a user is a member of', vcr: { cassette_name: 'slack/users_conversations_conversations_members' } do
      expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with(
        {
          message: 'message',
          channel: 'C0HNSS6H5',
          as_user: true
        }
      ).and_return(ts: '1503425956.000247')
      expect(user.inform!(message: 'message').count).to eq(1)
    end

    it 'does not send messages for a deleted user', vcr: { cassette_name: 'slack/users_info_deleted' } do
      expect_any_instance_of(Slack::Web::Client).not_to receive(:chat_postMessage)
      expect(user.inform!(message: 'message')).to be_nil
    end

    it 'handles user not found', vcr: { cassette_name: 'slack/users_info_not_found' } do
      expect_any_instance_of(Slack::Web::Client).not_to receive(:chat_postMessage)
      expect(user.inform!(message: 'message')).to be_nil
    end
  end

  describe '#dm_connect!' do
    let(:user) { Fabricate(:user) }
    let(:url) { "https://www.strava.com/oauth/authorize?client_id=client-id&redirect_uri=https://slava.playplay.io/connect&response_type=code&scope=activity:read_all&state=#{user.id}" }

    it 'uses the default message' do
      expect(user).to receive(:dm!).with(
        {
          text: 'Please connect your Strava account.',
          attachments: [{
            fallback: "Please connect your Strava account at #{url}.",
            actions: [{
              type: 'button',
              text: 'Click Here',
              url: url
            }]
          }]
        }
      )
      user.dm_connect!
    end

    it 'uses a custom message' do
      expect(user).to receive(:dm!).with(
        {
          text: 'Please reconnect your account.',
          attachments: [{
            fallback: "Please reconnect your account at #{url}.",
            actions: [{
              type: 'button',
              text: 'Click Here',
              url: url
            }]
          }]
        }
      )
      user.dm_connect!('Please reconnect your account')
    end
  end

  context 'sync_strava_activity!', vcr: { cassette_name: 'strava/user_sync_new_strava_activities' } do
    let!(:user) { Fabricate(:user, access_token: 'token', token_expires_at: Time.now + 1.day, token_type: 'Bearer') }

    context 'with a mismatched athlete ID' do
      it 'raises an exception' do
        expect {
          user.sync_strava_activity!('1473024961')
        }.to raise_error(/Activity athlete ID 26462176 does not match/)
      end
    end

    context 'with a matching athlete ID' do
      before do
        user.athlete.athlete_id = '26462176'
      end

      it 'fetches an activity' do
        expect {
          user.sync_strava_activity!('1473024961')
        }.to change(user.activities, :count).by(1)
        expect(user.activities.count).to eq 1
      end
    end
  end

  context 'sync_activity_and_brag!' do
    let!(:user) { Fabricate(:user) }
    let(:activity_id) { '1473024961' }

    it 'syncs an activity and brags' do
      expect_any_instance_of(User).to receive(:sync_strava_activity!).with(activity_id)
      expect_any_instance_of(User).to receive(:brag!)
      user.sync_activity_and_brag!(activity_id)
    end

    pending 'takes a lock'
  end

  describe '#rebrag_activity!', vcr: { cassette_name: 'strava/user_sync_new_strava_activities' } do
    let!(:user) { Fabricate(:user, access_token: 'token', token_expires_at: Time.now + 1.day, token_type: 'Bearer') }
    let!(:activity) { Fabricate(:user_activity, user: user, team: user.team, strava_id: '1473024961') }

    context 'a previously bragged activity' do
      before do
        activity.update_attributes!(
          bragged_at: Time.now.utc,
          channel_messages: [ChannelMessage.new(channel: 'channel1')]
        )
      end

      it 'rebrags' do
        expect_any_instance_of(UserActivity).not_to receive(:brag!)
        expect_any_instance_of(UserActivity).to receive(:rebrag!)
        user.rebrag_activity!(activity)
      end
    end

    context 'a new activity' do
      it 'does not rebrag' do
        expect_any_instance_of(UserActivity).not_to receive(:brag!)
        expect_any_instance_of(UserActivity).not_to receive(:rebrag!)
        user.rebrag_activity!(activity)
      end
    end
  end

  describe '#destroy' do
    context 'without an access token' do
      let!(:user) { Fabricate(:user) }

      it 'revokes access token' do
        expect_any_instance_of(Strava::Api::Client).not_to receive(:deauthorize)
        user.destroy
      end
    end

    context 'with an access token' do
      let!(:user) { Fabricate(:user, access_token: 'token', token_expires_at: Time.now + 1.day, token_type: 'Bearer') }

      it 'revokes access token' do
        expect(user.strava_client).to receive(:deauthorize)
          .with(access_token: user.access_token)
          .and_return(access_token: user.access_token)
        user.destroy
      end
    end

    describe '#medal_s' do
      let!(:user) { Fabricate(:user) }

      it 'no activities' do
        expect(user.medal_s('Run')).to be_nil
      end

      context 'with an activity' do
        let!(:activity) { Fabricate(:user_activity, user: user) }

        context 'ranked first' do
          before do
            Fabricate(:user_activity, user: Fabricate(:user, team: user.team), distance: activity.distance - 1)
          end

          it 'returns a gold medal' do
            expect(user.medal_s('Run')).to eq '🥇'
          end
        end

        {
          0 => '🥇',
          1 => '🥈',
          2 => '🥉',
          3 => nil
        }.each_pair do |count, medal|
          context "ranked #{count + 1}" do
            before do
              count.times { Fabricate(:user_activity, user: Fabricate(:user, team: user.team), distance: activity.distance + 1) }
            end

            it "returns #{medal}" do
              expect(user.medal_s('Run')).to eq medal
            end
          end
        end
      end

      context 'with an activity of a different type' do
        let!(:activity) { Fabricate(:user_activity, user: user) }

        context 'ranked first' do
          before do
            Fabricate(:swim_activity, user: user)
          end

          it 'returns a gold medal' do
            expect(user.medal_s('Swim')).to eq '🥈'
          end

          it 'returns a silver medal' do
            expect(user.medal_s('Run')).to eq '🥇'
          end
        end
      end
    end
  end
end
