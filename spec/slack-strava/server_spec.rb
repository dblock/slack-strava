require 'spec_helper'

describe SlackStrava::Server do
  let(:team) { Fabricate(:team) }
  let(:client) { subject.send(:client) }
  subject do
    SlackStrava::Server.new(team: team)
  end
  context '#channel_joined' do
    it 'sends a welcome message' do
      allow(client).to receive(:self).and_return(Hashie::Mash.new(id: 'U12345'))
      message = 'Welcome to Slava! Please DM "*connect*" to <@U12345> to publish your activities in this channel.'
      expect(client).to receive(:say).with(channel: 'C12345', text: message)
      client.send(:callback, Hashie::Mash.new('channel' => { 'id' => 'C12345' }), :channel_joined)
    end
  end
  context '#member_joined_channel' do
    let(:user) { Fabricate(:user, team: team) }
    let(:connect_url) { "https://www.strava.com/oauth/authorize?client_id=&redirect_uri=https://slava.playplay.io/connect&response_type=code&scope=view_private&state=#{user.id}" }
    it 'offers to connect account', vcr: { cassette_name: 'slack/user_info' } do
      allow(client).to receive(:self).and_return(Hashie::Mash.new(id: 'U12345'))
      allow(User).to receive(:find_create_or_update_by_slack_id!).and_return(user)
      expect(user).to receive(:dm!).with(
        text: 'Got a Strava account? I can post your activities to <#C12345> automatically.',
        attachments: [
          {
            fallback: "Got a Strava account? I can post your activities to <#C12345> automatically. Connect it at #{connect_url}.",
            actions: [
              {
                type: 'button',
                text: 'Click Here',
                url: connect_url
              }
            ]
          }
        ]
      )
      client.send(:callback, Hashie::Mash.new('user' => 'U12345', 'channel' => 'C12345'), :member_joined_channel)
    end
  end
end
