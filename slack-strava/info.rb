module SlackStrava
  INFO = <<~EOS.freeze
    Slack bot, powered by Strava #{SlackStrava::VERSION}

    © 2018-2019 Daniel Doubrovkine, Vestris LLC & Contributors, MIT License
    https://www.vestris.com

    Service at #{SlackRubyBotServer::Service.url}
    Open-Source at https://github.com/dblock/slack-strava
  EOS
end
