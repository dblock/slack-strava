module SlackStrava
  class Server < SlackRubyBotServer::Server
    CHANNEL_JOINED_MESSAGE = <<~EOS.freeze
      Thanks for installing Strava! Type `@strava help` for more commands.
    EOS

    on :channel_joined do |client, data|
      logger.info "#{client.owner.name}: joined ##{data.channel['name']}."
      client.say(channel: data.channel['id'], text: CHANNEL_JOINED_MESSAGE)
    end
  end
end
