module SlackStrava
  module Commands
    class Stats < SlackRubyBot::Commands::Base
      include SlackStrava::Commands::Mixins::Subscribe

      subscribe_command 'stats' do |client, data, _match|
        client.web_client.chat_postMessage(client.owner.stats.to_slack.merge(channel: data.channel, as_user: true))
        logger.info "STATS: #{client.owner}, user=#{data.user}"
      end
    end
  end
end
