module SlackStrava
  module Commands
    module Mixins
      module Subscribe
        extend ActiveSupport::Concern

        module ClassMethods
          def subscribe_command(*values, &_block)
            command(*values) do |client, data, match|
              if Stripe.api_key && client.owner.reload.subscription_expired?
                client.say channel: data.channel, text: client.owner.subscribe_text
                logger.info "#{client.owner}, user=#{data.user}, text=#{data.text}, subscription expired"
              else
                yield client, data, match
              end
            end
          end
        end
      end
    end
  end
end
