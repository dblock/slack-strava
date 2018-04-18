module SlackStrava
  module Commands
    class Connect < SlackRubyBot::Commands::Base
      include SlackStrava::Commands::Mixins::Subscribe

      subscribe_command 'connect' do |client, data, _match|
        logger.info "CONNECT: #{client.owner}, user=#{data.user}"
        user = ::User.find_create_or_update_by_slack_id!(client, data.user)
        user.dm_connect!
      end
    end
  end
end
