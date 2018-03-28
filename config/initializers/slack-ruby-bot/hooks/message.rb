module SlackRubyBot
  module Hooks
    class Message
      # HACK: order command classes predictably
      def command_classes
        [
          SlackStrava::Commands::Help,
          SlackStrava::Commands::Subscription
        ]
      end
    end
  end
end
