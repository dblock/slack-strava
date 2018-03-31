module SlackStrava
  module Commands
    class Connect < SlackRubyBot::Commands::Base
      include SlackStrava::Commands::Mixins::Subscribe

      subscribe_command 'connect' do |client, data, _match|
        logger.info "CONNECT: #{client.owner}, user=#{data.user}"
        user = ::User.find_create_or_update_by_slack_id!(client, data.user)
        redirect_uri = "#{SlackStrava::Service.url}/connect"
        url = "https://www.strava.com/oauth/authorize?client_id=#{ENV['STRAVA_CLIENT_ID']}&redirect_uri=#{redirect_uri}&response_type=code&scope=view_private&state=#{user.id}"
        client.web_client.chat_postMessage channel: data.channel, as_user: true, text: 'Please connect your Strava account.', attachments: [
          fallback: "Connect your Strava account at #{url}",
          actions: [
            type: 'button',
            text: 'Click Here',
            url: url
          ]
        ]
      end
    end
  end
end
