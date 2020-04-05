module SlackStrava
  module Commands
    class Stats < SlackRubyBot::Commands::Base
      include SlackStrava::Commands::Mixins::Subscribe

      subscribe_command 'stats' do |client, data, _match|
        channel_options = {}
        channel_options.merge!(channel_id: data.channel) unless data.channel[0] == 'D'
        client.web_client.chat_postMessage(
          client.owner.stats(
            channel_options
          ).to_slack.merge(channel: data.channel, as_user: true)
        )
        logger.info "STATS: #{client.owner}, user=#{data.user}, channel=#{data.channel}"
      end
    end
  end
end
