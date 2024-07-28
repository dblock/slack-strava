require 'spec_helper'

describe 'Homepage', js: true, type: :feature do
  before do
    ENV['SLACK_CLIENT_ID'] = 'client_id'
    ENV['SLACK_CLIENT_SECRET'] = 'client_secret'
    ENV['SLACK_OAUTH_SCOPE'] = 'scope:read'
    visit '/'
  end
  after do
    ENV.delete 'SLACK_CLIENT_ID'
    ENV.delete 'SLACK_CLIENT_SECRET'
    ENV.delete 'SLACK_OAUTH_SCOPE'
  end
  it 'displays index.html page' do
    expect(title).to eq('Slava: Strava integration with Slack')
  end
  it 'includes a link to add to slack with the client id' do
    expect(find("a[href='https://slack.com/oauth/authorize?scope=scope:read&client_id=client_id']"))
  end
end
