module SlackStrava
  module Commands
    class Stats < SlackRubyBot::Commands::Base
      include SlackStrava::Commands::Mixins::Subscribe

      class << self
        include SlackStrava::Commands::Mixins::ParseDate
      end

      subscribe_command 'stats' do |client, data, match|
        stats_options = begin
          Stats.parse_date_expression(match['expression'], now: client.owner.now)
        rescue SlackStrava::Error
          {}
        end
        stats_options[:channel_id] = data.channel unless data.channel[0] == 'D'
        client.web_client.chat_postMessage(
          client.owner.stats(stats_options).to_slack.merge(channel: data.channel, as_user: true)
        )
        logger.info "STATS: #{client.owner}, user=#{data.user}, dates=#{stats_options[:start_date]}..#{stats_options[:end_date]}, channel=#{data.channel}"
      end
    end
  end
end
