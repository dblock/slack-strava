module SlackStrava
  class Server < SlackRubyBotServer::Server
    on :channel_joined do |client, data|
      message = "Welcome to Slava! Please DM \"*connect*\" to <@#{client.self.id}> to publish your activities in this channel."
      logger.info "#{client.owner.name}: joined ##{data.channel['name']}."
      client.say(channel: data.channel['id'], text: message)
    end

    on :member_joined_channel do |client, data|
      user = ::User.find_create_or_update_by_slack_id!(client, data.user)
      if user.is_bot
        logger.info "#{client.owner.name}: #{user.user_name} (@#{data.user}) joined ##{data.channel}, bot"
      elsif user.connected_to_strava?
        logger.info "#{client.owner.name}: #{user.user_name} (@#{data.user}) joined ##{data.channel}, already connected to Strava"
      else
        logger.info "#{client.owner.name}: #{user.user_name} (@#{data.user}) joined ##{data.channel}, connecting to Strava"
        url = user.connect_to_strava_url
        message = "Got a Strava account? I can post your activities to <##{data.channel}> automatically."
        user.dm!(
          text: message, attachments: [
            fallback: "#{message} Connect it at #{url}.",
            actions: [
              type: 'button',
              text: 'Click Here',
              url: url
            ]
          ]
        )
      end
    end

    on :user_change do |client, data|
      user = User.where(team: client.owner, user_id: data.user.id).first
      next unless user && user.user_name != data.user.name

      logger.info "RENAME: #{user.user_id}, #{user.user_name} => #{data.user.name}"
      user.update_attributes!(user_name: data.user.name)
    end
  end
end
