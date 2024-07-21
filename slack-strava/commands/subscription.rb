module SlackStrava
  module Commands
    class Subscription < SlackRubyBot::Commands::Base
      include SlackStrava::Commands::Mixins::Subscribe

      subscribe_command 'subscription' do |client, data, _match|
        user = ::User.find_create_or_update_by_slack_id!(client, data.user)
        team = ::Team.find(client.owner.id)
        client.say(channel: data.channel, text: team.subscription_info(user.team_admin?))
        logger.info "SUBSCRIPTION: #{client.owner} - #{data.user}"
      end
    end
  end
end
