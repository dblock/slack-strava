module SlackRubyBot
  module Hooks
    class Message
      # HACK: order command classes predictably
      def command_classes
        [
          SlackStrava::Commands::Help,
          SlackStrava::Commands::Info,
          SlackStrava::Commands::Stats,
          SlackStrava::Commands::Subscription,
          SlackStrava::Commands::Unsubscribe,
          SlackStrava::Commands::Connect,
          SlackStrava::Commands::Disconnect,
          SlackStrava::Commands::Set
        ]
      end
    end
  end
end
