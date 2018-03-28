require 'spec_helper'

describe SlackStrava::Server do
  let(:team) { Fabricate(:team) }
  let(:client) { subject.send(:client) }
  subject do
    SlackStrava::Server.new(team: team)
  end
  context '#channel_joined' do
    it 'sends a welcome message' do
      expect(client).to receive(:say).with(channel: 'C12345', text: SlackStrava::Server::CHANNEL_JOINED_MESSAGE)
      client.send(:callback, Hashie::Mash.new('channel' => { 'id' => 'C12345' }), :channel_joined)
    end
  end
end
