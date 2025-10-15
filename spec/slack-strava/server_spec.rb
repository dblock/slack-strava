require 'spec_helper'

describe SlackStrava::Server do
  let(:team) { Fabricate(:team) }
  let(:server) { described_class.new(team: team) }
  let(:client) { server.send(:client) }

  describe '#channel_joined' do
    it 'sends a welcome message' do
      allow(client).to receive(:self).and_return(Hashie::Mash.new(id: 'U12345'))
      message = 'Welcome to Slava! Please DM "*connect*" to <@U12345> to publish your activities in this channel.'
      expect(client).to receive(:say).with(channel: 'C12345', text: message)
      client.send(:callback, Hashie::Mash.new('channel' => { 'id' => 'C12345' }), :channel_joined)
    end
  end

  describe '#member_joined_channel' do
    let(:user) { Fabricate(:user, team: team) }
    let(:connect_url) { "https://www.strava.com/oauth/authorize?client_id=client-id&redirect_uri=https://slava.playplay.io/connect&response_type=code&scope=activity:read_all&state=#{user.id}" }

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

  context 'hooks' do
    let(:user) { Fabricate(:user, team: team) }

    it 'renames user' do
      client.send(:callback, Hashie::Mash.new(user: { id: user.user_id, name: 'updated' }), :user_change)
      expect(user.reload.user_name).to eq('updated')
    end

    it 'does not touch a user with the same name' do
      expect(User).to receive(:where).and_return([user])
      expect(user).not_to receive(:update_attributes!)
      client.send(:callback, Hashie::Mash.new(user: { id: user.user_id, name: user.user_name }), :user_change)
    end
  end
end
