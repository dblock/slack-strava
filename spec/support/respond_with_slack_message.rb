# Extends the upstream respond_with_slack_message matcher to assert that
# exactly one message is sent per command invocation. This catches bugs where
# a LocalJumpError (or any other unhandled error) causes the RTM server error
# handler to emit a second message via client.say.
RSpec::Matchers.define :respond_with_slack_message do |expected|
  include SlackRubyBot::SpecHelpers

  match do |actual|
    client = respond_to?(:client) ? send(:client) : SlackRubyBot::Client.new

    message_command = SlackRubyBot::Hooks::Message.new
    channel, user, message, attachments = parse(actual)

    @messages = []
    allow(client).to receive(:message) do |options|
      @messages.push options
    end

    message_command.call(client, Hashie::Mash.new(text: message, channel: channel, user: user, attachments: attachments))

    matcher = have_received(:message).once
    matcher = matcher.with(hash_including(channel: channel, text: expected)) if channel && expected

    expect(client).to matcher
    expect(@messages.size).to eq(1), "expected exactly 1 message, got #{@messages.size}: #{@messages.map { |m| m[:text] }.inspect}"

    true
  end

  failure_message do |_actual|
    message = "expected to receive message with text: #{expected} once,\n received:"
    message += @messages&.any? ? @messages.inspect : 'none'
    message
  end
end
