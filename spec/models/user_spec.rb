require 'spec_helper'

describe User do
  context '#find_by_slack_mention!' do
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
  context '#find_create_or_update_by_slack_id!', vcr: { cassette_name: 'slack/user_info' } do
    let!(:team) { Fabricate(:team) }
    let(:client) { SlackRubyBot::Client.new }
    before do
      client.owner = team
    end
    context 'without a user' do
      it 'creates a user' do
        expect {
          user = User.find_create_or_update_by_slack_id!(client, 'U42')
          expect(user).to_not be_nil
          expect(user.user_id).to eq 'U42'
          expect(user.user_name).to eq 'username'
        }.to change(User, :count).by(1)
      end
    end
    context 'with a user' do
      let!(:user) { Fabricate(:user, team: team) }
      it 'creates another user' do
        expect {
          User.find_create_or_update_by_slack_id!(client, 'U42')
        }.to change(User, :count).by(1)
      end
      it 'updates the username of the existing user' do
        expect {
          User.find_create_or_update_by_slack_id!(client, user.user_id)
        }.to_not change(User, :count)
        expect(user.reload.user_name).to eq 'username'
      end
    end
  end
  context 'sync_last_strava_activity!', vcr: { allow_playback_repeats: true, cassette_name: 'strava/user_sync_last_strava_activity' } do
    let!(:user) { Fabricate(:user, access_token: 'token', token_type: 'Bearer') }
    it 'retrieves the last activity' do
      expect {
        user.sync_last_strava_activity!
      }.to change(user.activities, :count).by(1)
      activity = user.activities.last
      expect(activity.strava_id).to eq '1484119264'
      expect(activity.name).to eq 'Reservoir Dogs'
      expect(activity.map.id).to be_a BSON::ObjectId
      expect(activity.map.strava_id).to_not be nil
      expect(activity.map.png.data.size).to eq 69_234
    end
    it 'only saves the last activity once' do
      expect {
        2.times { user.sync_last_strava_activity! }
      }.to change(user.activities, :count).by(1)
    end
    it 'disconnects user on auth failure' do
      allow(user.strava_client).to receive(:list_athlete_activities).and_raise(
        Strava::Api::V3::ClientError.new(401, '{"message":"Authorization Error","errors":[{"resource":"Athlete","field":"access_token","code":"invalid"}]}')
      )
      expect(user).to receive(:dm_connect!).with('There was an authorization problem. Please reconnect your Strava account')
      expect { user.sync_last_strava_activity! }.to raise_error Strava::Api::V3::ClientError
      expect(user.access_token).to be nil
    end
  end
  context 'sync_last_strava_activity! with private activities', vcr: { cassette_name: 'strava/user_sync_last_strava_activity_with_private' } do
    let!(:user) { Fabricate(:user, created_at: DateTime.new(2018, 3, 26), access_token: 'token', token_type: 'Bearer') }
    context 'by default' do
      it 'skips private activities' do
        expect {
          user.sync_last_strava_activity!
        }.to_not change(user.activities, :count)
      end
    end
    context 'with private_activities set to true' do
      before do
        user.update_attributes!(private_activities: true)
      end
      it 'skips private activities' do
        expect {
          user.sync_last_strava_activity!
        }.to change(user.activities, :count).by(1)
      end
    end
  end
  context 'sync_new_strava_activities!' do
    context 'recent created_at', vcr: { cassette_name: 'strava/user_sync_new_strava_activities' } do
      let!(:user) { Fabricate(:user, created_at: DateTime.new(2018, 3, 26), access_token: 'token', token_type: 'Bearer') }
      it 'retrieves new activities since created_at' do
        expect {
          user.sync_new_strava_activities!
        }.to change(user.activities, :count).by(3)
      end
      it 'sets activities_at to nil without any bragged activity' do
        user.sync_new_strava_activities!
        expect(user.activities_at).to be nil
      end
      context 'with bragged activities' do
        before do
          user.sync_new_strava_activities!
          allow_any_instance_of(User).to receive(:inform!)
          user.brag!
        end
        it 'sets activities_at to the most recent bragged activity' do
          expect(user.activities_at).to eq user.activities.bragged.max(:start_date)
        end
        it 'updates activities since activities_at' do
          expect(user).to receive(:sync_strava_activities!).with(after: user.activities_at)
          user.sync_new_strava_activities!
        end
      end
    end
    context 'old created_at' do
      let!(:user) { Fabricate(:user, created_at: DateTime.new(2018, 2, 1), access_token: 'token', token_type: 'Bearer') }
      it 'retrieves multiple pages of activities', vcr: { cassette_name: 'strava/user_sync_new_strava_activities_many' } do
        expect {
          user.sync_new_strava_activities!
        }.to change(user.activities, :count).by(14)
      end
    end
    context 'with private activities', vcr: { cassette_name: 'strava/user_sync_new_strava_activities_with_private' } do
      let!(:user) { Fabricate(:user, created_at: DateTime.new(2018, 3, 26), access_token: 'token', token_type: 'Bearer') }
      context 'by default' do
        it 'skips private activities' do
          expect {
            user.sync_new_strava_activities!
          }.to change(user.activities, :count).by(3)
          expect(user.activities.select(&:private).count).to eq 0
        end
      end
      context 'with private_activities set to true' do
        before do
          user.update_attributes!(private_activities: true)
        end
        it 'skips private activities' do
          expect {
            user.sync_new_strava_activities!
          }.to change(user.activities, :count).by(4)
          expect(user.activities.select(&:private).count).to eq 1
        end
      end
    end
  end
  context 'brag!' do
    let!(:user) { Fabricate(:user) }
    before do
      expect(HTTParty).to receive_message_chain(:get, :body).and_return('PNG')
    end
    it 'brags the last unbragged activity' do
      activity = Fabricate(:user_activity, user: user)
      expect_any_instance_of(UserActivity).to receive(:brag!).and_return(
        [
          ts: '1503435956.000247',
          channel: {
            id: 'C1',
            name: 'channel'
          }
        ]
      )
      results = user.brag!
      expect(results.size).to eq(1)
      expect(results.first[:ts]).to eq '1503435956.000247'
      expect(results.first[:channel]).to eq(id: 'C1', name: 'channel')
      expect(results.first[:activity]).to eq activity
    end
  end
  context '#inform!' do
    let(:user) { Fabricate(:user, user_id: 'U0HLFUZLJ') }
    it 'sends message to all channels a user is a member of', vcr: { cassette_name: 'slack/channels_list_conversations_members' } do
      expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with(
        message: 'message',
        channel: 'C0HNSS6H5',
        as_user: true
      ).and_return(ts: '1503435956.000247')
      expect(user.inform!(message: 'message').count).to eq(1)
    end
  end
  context '#dm_connect!' do
    let(:user) { Fabricate(:user) }
    let(:url) { "https://www.strava.com/oauth/authorize?client_id=&redirect_uri=https://slava.playplay.io/connect&response_type=code&scope=view_private&state=#{user.id}" }
    it 'uses the default message' do
      expect(user).to receive(:dm!).with(
        text: 'Please connect your Strava account.',
        attachments: [{
          fallback: "Please connect your Strava account at #{url}.",
          actions: [{
            type: 'button',
            text: 'Click Here',
            url: url
          }]
        }]
      )
      user.dm_connect!
    end
    it 'uses a custom message' do
      expect(user).to receive(:dm!).with(
        text: 'Please reconnect your account.',
        attachments: [{
          fallback: "Please reconnect your account at #{url}.",
          actions: [{
            type: 'button',
            text: 'Click Here',
            url: url
          }]
        }]
      )
      user.dm_connect!('Please reconnect your account')
    end
  end
end
