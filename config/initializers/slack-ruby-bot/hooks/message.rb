module SlackRubyBot
  module Hooks
    class Message
      # HACK: order command classes predictably
      def command_classes
        [
          SlackStrava::Commands::Help,
          SlackStrava::Commands::Info,
          SlackStrava::Commands::Subscription,
          SlackStrava::Commands::Connect,
          SlackStrava::Commands::Disconnect,
          SlackStrava::Commands::Set,
          SlackStrava::Commands::Clubs
        ]
      end
    end
  end
end
