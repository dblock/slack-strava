module SlackStrava
  module Commands
    class Leaderboard < SlackRubyBot::Commands::Base
      include SlackStrava::Commands::Mixins::Subscribe

      class << self
        include SlackStrava::Commands::Mixins::ParseDate

        def parse_expression(expression, now: Time.now)
          result = { metric: 'distance' }
          return result if expression.nil?

          expression = expression.strip

          TeamLeaderboard::MEASURABLE_VALUES.each do |metric|
            next unless expression.match?(/^#{Regexp.escape(metric)}(?:\s|$)/i)

            result[:metric] = metric.downcase
            expression = expression[metric.length..]&.strip
            break
          end

          result.merge(parse_date_expression(expression, now: now))
        end
      end

      subscribe_command 'leaderboard' do |client, data, match|
        leaderboard_options = Leaderboard.parse_expression(match['expression'] || client.owner.default_leaderboard, now: client.owner.now)
        leaderboard_options = leaderboard_options.merge(channel_id: data.channel) unless data.channel[0] == 'D'
        leaderboard_s = client.owner.leaderboard(leaderboard_options).to_s
        client.web_client.chat_postMessage(
          as_user: true,
          channel: data.channel,
          text: leaderboard_s
        )
        logger.info "LEADERBOARD: #{client.owner}, user=#{data.user}, metric=#{leaderboard_options[:metric]}, dates=#{leaderboard_options[:start_date]}..#{leaderboard_options[:end_date]}, channel=#{data.channel}"
      end
    end
  end
end
