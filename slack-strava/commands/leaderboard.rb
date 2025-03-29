module SlackStrava
  module Commands
    class Leaderboard < SlackRubyBot::Commands::Base
      include SlackStrava::Commands::Mixins::Subscribe

      class << self
        def parse_year(date_time)
          return unless date_time.match?(/^\d{2,4}$/)

          year = date_time.to_i
          year += 2000 if year < 100
          Time.new(year, 1, 1)
        end

        def parse_date(date_time, guess = :first)
          if year = Leaderboard.parse_year(date_time)
            year
          else
            parsed = Chronic.parse(date_time, context: :past, guess: false)
            if parsed.is_a?(Chronic::Span)
              parsed.send(guess)
            elsif parsed.is_a?(Time)
              parsed
            else
              raise SlackStrava::Error, "Sorry, I don't understand '#{date_time}'."
            end
          end
        end

        def parse_expression(expression)
          result = { metric: 'distance' }
          return result if expression.nil?

          expression = expression.strip

          TeamLeaderboard::MEASURABLE_VALUES.each do |metric|
            next unless expression.match?(/^#{Regexp.escape(metric)}(?:\s|$)/i)

            result[:metric] = metric.downcase
            expression = expression[metric.length..]&.strip
            break
          end

          if expression.match?(/^between(\s)/i)
            expression = expression[('between'.length)..]&.strip
            dates = expression.strip.split(/\s+and\s+/)
            raise SlackStrava::Error, "Sorry, I don't understand '#{expression}'." unless dates.length == 2

            result[:start_date] = Leaderboard.parse_date(dates[0], :first)
            result[:end_date] = Leaderboard.parse_date(dates[1], :last)
          else
            if expression.match?(/^since(\s)/i)
              expression = expression[('since'.length)..]&.strip
              result[:end_date] = Time.now
            end

            if expression.blank?
              # pass
            elsif year = Leaderboard.parse_year(expression)
              result[:start_date] = year
              result[:end_date] ||= year.end_of_year
            else
              parsed = Chronic.parse(expression, context: :past, guess: false)
              if parsed.is_a?(Chronic::Span)
                result[:start_date] = parsed.first
                result[:end_date] ||= parsed.last
              elsif parsed.is_a?(Time)
                result[:start_date] = parsed
              else
                raise SlackStrava::Error, "Sorry, I don't understand '#{expression}'."
              end
            end
          end

          result
        end
      end

      subscribe_command 'leaderboard' do |client, data, match|
        leaderboard_options = Leaderboard.parse_expression(match['expression'] || client.owner.default_leaderboard)
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
