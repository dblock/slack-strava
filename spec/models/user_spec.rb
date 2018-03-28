require 'spec_helper'

describe User do
  context '#find_by_slack_mention!' do
    before do
      @user = Fabricate(:user)
    end
    it 'finds by slack id' do
      expect(User.find_by_slack_mention!(@user.team, "<@#{@user.user_id}>")).to eq @user
    end
    it 'finds by username' do
      expect(User.find_by_slack_mention!(@user.team, @user.user_name)).to eq @user
    end
    it 'finds by username is case-insensitive' do
      expect(User.find_by_slack_mention!(@user.team, @user.user_name.capitalize)).to eq @user
    end
    it 'requires a known user' do
      expect do
        User.find_by_slack_mention!(@user.team, '<@nobody>')
      end.to raise_error SlackStrava::Error, "I don't know who <@nobody> is!"
    end
  end
  context '#find_create_or_update_by_slack_id!', vcr: { cassette_name: 'user_info' } do
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
      before do
        @user = Fabricate(:user, team: team)
      end
      it 'creates another user' do
        expect do
          User.find_create_or_update_by_slack_id!(client, 'U42')
        end.to change(User, :count).by(1)
      end
      it 'updates the username of the existing user' do
        expect do
          User.find_create_or_update_by_slack_id!(client, @user.user_id)
        end.to_not change(User, :count)
        expect(@user.reload.user_name).to eq 'username'
      end
    end
  end
end
