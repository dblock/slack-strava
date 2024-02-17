module SlackStrava
  module Commands
    class Leaderboard < SlackRubyBot::Commands::Base
      include SlackStrava::Commands::Mixins::Subscribe

      subscribe_command 'leaderboard' do |client, data, match|
        leaderboard_options = {}
        leaderboard_options.merge!(channel_id: data.channel) unless data.channel[0] == 'D'
        leaderboard_options.merge!(metric: match['expression'] || 'distance')
        leaderboard_s = client.owner.leaderboard(leaderboard_options).to_s
        client.web_client.chat_postMessage(
          as_user: true,
          channel: data.channel,
          text: leaderboard_s
        )
        logger.info "LEADERBOARD: #{client.owner}, user=#{data.user}, metric=#{leaderboard_options[:metric]}, channel=#{data.channel}"
      end
    end
  end
end
