module SlackStrava
  class Server < SlackRubyBotServer::Server
    CHANNEL_JOINED_MESSAGE = <<~EOS.freeze
      Welcome to Strava on Slack! Ask users to DM `connect` to `@strava` to enable notifications of their activities in this channel.
    EOS

    on :channel_joined do |client, data|
      logger.info "#{client.owner.name}: joined ##{data.channel['name']}."
      client.say(channel: data.channel['id'], text: CHANNEL_JOINED_MESSAGE)
    end
  end
end
