module SlackStrava
  module Commands
    class Connect < SlackRubyBot::Commands::Base
      include SlackStrava::Commands::Mixins::Subscribe

      subscribe_command 'connect' do |client, data, _match|
        logger.info "CONNECT: #{client.owner}, user=#{data.user}"
        user = ::User.find_create_or_update_by_slack_id!(client, data.user)
        url = user.connect_to_strava_url
        user.dm!(
          text: 'Please connect your Strava account.', attachments: [
            fallback: "Connect your Strava account at #{url}.",
            actions: [
              type: 'button',
              text: 'Click Here',
              url: url
            ]
          ]
        )
      end
    end
  end
end
