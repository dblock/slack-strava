module SlackStrava
  module Commands
    class Info < SlackRubyBot::Commands::Base
      def self.call(client, data, _match)
        client.say(channel: data.channel, text: [
          SlackStrava::INFO,
          client.owner.reload.subscribed? ? nil : client.owner.subscribe_text
        ].compact.join("\n"))
        logger.info "INFO: #{client.owner}, user=#{data.user}"
      end
    end
  end
end
