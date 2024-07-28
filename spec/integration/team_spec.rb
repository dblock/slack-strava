require 'spec_helper'

describe 'Teams', :js, type: :feature do
  before do
    ENV['SLACK_CLIENT_ID'] = 'client_id'
    ENV['SLACK_CLIENT_SECRET'] = 'client_secret'
    ENV['SLACK_OAUTH_SCOPE'] = 'bot,commands,links:read,links:write'
  end

  after do
    ENV.delete 'SLACK_CLIENT_ID'
    ENV.delete 'SLACK_CLIENT_SECRET'
    ENV.delete 'SLACK_OAUTH_SCOPE'
  end

  context 'oauth', vcr: { cassette_name: 'auth_test' } do
    it 'registers a team' do
      allow_any_instance_of(Team).to receive(:ping!).and_return(ok: true)
      expect(SlackRubyBotServer::Service.instance).to receive(:start!)
      oauth_access = { 'bot' => { 'bot_access_token' => 'token' }, 'team_id' => 'team_id', 'team_name' => 'team_name' }
      allow_any_instance_of(Slack::Web::Client).to receive(:oauth_access).with(hash_including(code: 'code')).and_return(oauth_access)
      expect {
        visit '/?code=code'
        expect(page.find_by_id('messages')).to have_content 'Team successfully registered!'
      }.to change(Team, :count).by(1)
    end
  end
end
