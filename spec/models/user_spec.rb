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
      expect do
        User.find_by_slack_mention!(user.team, '<@nobody>')
      end.to raise_error SlackStrava::Error, "I don't know who <@nobody> is!"
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
        expect do
          user = User.find_create_or_update_by_slack_id!(client, 'U42')
          expect(user).to_not be_nil
          expect(user.user_id).to eq 'U42'
          expect(user.user_name).to eq 'username'
        end.to change(User, :count).by(1)
      end
    end
    context 'with a user' do
      let!(:user) { Fabricate(:user, team: team) }
      it 'creates another user' do
        expect do
          User.find_create_or_update_by_slack_id!(client, 'U42')
        end.to change(User, :count).by(1)
      end
      it 'updates the username of the existing user' do
        expect do
          User.find_create_or_update_by_slack_id!(client, user.user_id)
        end.to_not change(User, :count)
        expect(user.reload.user_name).to eq 'username'
      end
    end
  end
  context 'sync_last_strava_activity!', vcr: { allow_playback_repeats: true, cassette_name: 'strava/sync_last_strava_activity' } do
    let!(:user) { Fabricate(:user, access_token: 'token', token_type: 'Bearer') }
    it 'retrieves the last activity' do
      expect do
        user.sync_last_strava_activity!
      end.to change(user.activities, :count).by(1)
      activity = user.activities.last
      expect(activity.strava_id).to eq '1484119264'
      expect(activity.name).to eq 'Reservoir Dogs'
      expect(activity.map.png.data.size).to eq 69_234
    end
    it 'only saves the last activity once' do
      expect do
        2.times { user.sync_last_strava_activity! }
      end.to change(user.activities, :count).by(1)
    end
  end
  context 'sync_new_strava_activities!' do
    context 'recent created_at', vcr: { cassette_name: 'strava/sync_new_strava_activities' } do
      let!(:user) { Fabricate(:user, created_at: DateTime.new(2018, 3, 26), access_token: 'token', token_type: 'Bearer') }
      it 'retrieves new activities since created_at' do
        expect do
          user.sync_new_strava_activities!
        end.to change(user.activities, :count).by(3)
      end
      it 'updates activities since activities_at' do
        user.sync_new_strava_activities!
        expect(user).to receive(:sync_strava_activities!).with(after: user.activities_at)
        user.sync_new_strava_activities!
      end
    end
    context 'old created_at' do
      let!(:user) { Fabricate(:user, created_at: DateTime.new(2018, 2, 1), access_token: 'token', token_type: 'Bearer') }
      it 'retrieves muliple pages of activities', vcr: { cassette_name: 'strava/sync_new_strava_activities_many' } do
        expect do
          user.sync_new_strava_activities!
        end.to change(user.activities, :count).by(14)
      end
    end
  end
  context 'brag!' do
    let!(:user) { Fabricate(:user) }
    before do
      expect(HTTParty).to receive_message_chain(:get, :body).and_return('PNG')
    end
    it 'brags the last unbragged activity' do
      activity = Fabricate(:activity, user: user)
      expect(user).to receive_message_chain(:activities, :unbragged, :asc).and_return [activity]
      expect(activity).to receive(:brag!).and_return(['channel'])
      returned_activity, channels = user.brag!
      expect(channels).to eq(['channel'])
      expect(returned_activity).to eq activity
    end
  end
end
