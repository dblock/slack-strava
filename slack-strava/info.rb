module SlackStrava
  INFO = <<~EOS.freeze
    I am Slava, a Slack bot powered by Strava #{SlackStrava::VERSION}.

    © 2018-2025 Daniel Doubrovkine, Vestris LLC & Contributors, Open-Source, MIT License
    https://www.vestris.com

    Service at #{SlackRubyBotServer::Service.url}
    Please report bugs or suggest features at https://github.com/dblock/slack-strava/issues.
  EOS
end
