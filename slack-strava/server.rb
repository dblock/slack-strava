module SlackStrava
  class Server < SlackRubyBotServer::Server
    on :channel_joined do |client, data|
      message = "Welcome to Strava on Slack! Please DM \"*connect*\" to <@#{client.self.id}> to publish your activities in this channel."
      logger.info "#{client.owner.name}: joined ##{data.channel['name']}."
      client.say(channel: data.channel['id'], text: message)
    end
  end
end
