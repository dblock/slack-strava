module SlackStrava
  module Commands
    class Disconnect < SlackRubyBot::Commands::Base
      include SlackStrava::Commands::Mixins::Subscribe

      subscribe_command 'disconnect' do |client, data, _match|
        logger.info "DISCONNECT: #{client.owner}, user=#{data.user}"
        user = ::User.find_create_or_update_by_slack_id!(client, data.user)
        user.disconnect!
      end
    end
  end
end
