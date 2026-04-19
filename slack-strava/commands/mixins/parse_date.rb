module SlackStrava
  module Commands
    module Mixins
      module ParseDate
        PERIOD_ALIASES = {
          'weekly' => 'this week',
          'monthly' => 'this month',
          'yearly' => 'this year'
        }.freeze

        def parse_year(date_time)
          return unless date_time.match?(/^\d{2,4}$/)

          year = date_time.to_i
          year += 2000 if year < 100
          Time.new(year, 1, 1)
        end

        def parse_date(date_time, guess = :first)
          if (year = parse_year(date_time))
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

        def normalize_period(expression)
          return expression if expression.blank?

          downcased = expression.strip.downcase
          if PERIOD_ALIASES.key?(downcased)
            PERIOD_ALIASES[downcased]
          elsif downcased == 'quarterly'
            quarter_start = Time.now.beginning_of_quarter
            expression.sub(/quarterly/i, "between #{quarter_start.strftime('%B %d %Y')} and now")
          else
            expression
          end
        end

        def parse_date_expression(expression)
          result = {}
          return result if expression.blank?

          expression = normalize_period(expression.strip)

          if expression.match?(/^between(\s)/i)
            expression = expression[('between'.length)..]&.strip
            dates = expression.strip.split(/\s+and\s+/)
            raise SlackStrava::Error, "Sorry, I don't understand '#{expression}'." unless dates.length == 2

            result[:start_date] = parse_date(dates[0], :first)
            result[:end_date] = parse_date(dates[1], :last)
          else
            if expression.match?(/^since(\s)/i)
              expression = expression[('since'.length)..]&.strip
              result[:end_date] = Time.now
            end

            if expression.blank?
              # pass
            elsif (year = parse_year(expression))
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
    end
  end
end
