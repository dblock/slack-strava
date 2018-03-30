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
      message = 'Welcome to Strava on Slack! Please DM "*connect*" to <@U12345> to publish your activities in this channel.'
      expect(client).to receive(:say).with(channel: 'C12345', text: message)
      client.send(:callback, Hashie::Mash.new('channel' => { 'id' => 'C12345' }), :channel_joined)
    end
  end
end
