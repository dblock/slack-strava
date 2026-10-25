require 'spec_helper'

describe Api::Endpoints::Requests::Command do
  let(:payload) do
    {
      channel: { id: 'C1', name: 'general' },
      user: { id: 'U1' },
      team: { id: 'T1' },
      token: 'verification-token',
      message: {
        text: 'Check this activity',
        ts: '123.456',
        attachments: [{ image_url: 'https://example.com/first.png' }, { text: 'No image' }, { image_url: 'https://example.com/second.png' }]
      }
    }
  end

  it 'combines message text and image attachments and falls back to the message timestamp' do
    command = described_class.new(payload: payload)
    expect(command.text).to eq "Check this activity\nhttps://example.com/first.png\nhttps://example.com/second.png"
    expect(command.message_ts).to eq '123.456'
  end

  it 'preserves an explicit timestamp and handles image-only messages without blank lines' do
    payload[:message_ts] = '789.012'
    payload[:message][:text] = nil
    payload[:message][:attachments] = [{ image_url: 'https://example.com/only.png' }]
    command = described_class.new(payload: payload)
    expect(command.message_ts).to eq '789.012'
    expect(command.text).to eq 'https://example.com/only.png'
  end

  it 'accepts a message without attachments' do
    payload[:message].delete(:attachments)
    expect(described_class.new(payload: payload).text).to eq 'Check this activity'
  end
end
