module SlackStrava
  INFO = <<~EOS.freeze
    Slack bot, powered by Strava #{SlackStrava::VERSION}

    © 2018 Daniel Doubrovkine & Contributors, MIT License
    https://twitter.com/dblockdotorg

    Service at #{SlackRubyBotServer::Service.url}
    Open-Source at https://github.com/dblock/slack-strava
  EOS
end
