require 'spec_helper'

describe Athlete do
  let(:user) { Fabricate(:user, access_token: 'token', token_expires_at: 2.hours.from_now) }

  it 'refreshes and persists the athlete profile returned by Strava' do
    profile = Hashie::Mash.new(
      id: 42, username: 'runner', firstname: 'Test', lastname: 'Runner',
      profile: 'https://example.com/large.png', profile_medium: 'https://example.com/small.png'
    )
    allow(user.strava_client).to receive(:athlete).and_return(profile)
    user.athlete.sync!
    expect(user.reload.athlete.attributes.slice('athlete_id', 'username', 'firstname', 'lastname', 'profile', 'profile_medium')).to eq(
      'athlete_id' => '42', 'username' => 'runner', 'firstname' => 'Test', 'lastname' => 'Runner',
      'profile' => 'https://example.com/large.png', 'profile_medium' => 'https://example.com/small.png'
    )
  end

  it 'renders a linked athlete profile and avatar in Slack context blocks' do
    athlete = described_class.new(athlete_id: '42', firstname: 'Test', lastname: 'Runner', profile_medium: 'https://example.com/small.png')
    expect(athlete.to_slack).to eq(
      type: 'context',
      elements: [
        { type: 'mrkdwn', text: '<https://www.strava.com/athletes/42|Test Runner>' },
        { type: 'image', image_url: 'https://example.com/small.png', alt_text: '' }
      ]
    )
  end
end
