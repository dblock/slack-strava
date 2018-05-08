module SlackStrava
  module Commands
    class Set < SlackRubyBot::Commands::Base
      include SlackStrava::Commands::Mixins::Subscribe

      subscribe_command 'set' do |client, data, match|
        user = ::User.find_create_or_update_by_slack_id!(client, data.user)
        if !match['expression']
          messages = [
            "Activities for team #{client.owner.name} display *#{client.owner.units_s}*.",
            "Maps for team #{client.owner.name} are *#{client.owner.maps_s}*.",
            "Your private activities will #{user.private_activities? ? '' : 'not'} be posted."
          ]
          client.say(channel: data.channel, text: messages.join("\n"))
          logger.info "SET: #{client.owner}, user=#{data.user} - set"
        else
          k, v = match['expression'].split(/\W+/, 2)
          case k
          when 'private' then
            changed = v && user.private_activities != v
            user.update_attributes!(private_activities: v) unless v.nil?
            client.say(channel: data.channel, text: "Your private activities will#{changed ? (user.private_activities? ? ' now' : ' no longer') : (user.private_activities? ? '' : ' not')} be posted.")
            logger.info "SET: #{client.owner}, user=#{data.user} - private set to #{user.private_activities}"
          when 'units' then
            changed = v && client.owner.units != v
            client.owner.update_attributes!(units: v) unless v.nil?
            client.say(channel: data.channel, text: "Activities for team #{client.owner.name}#{changed ? ' now' : ''} display *#{client.owner.units_s}*.")
            logger.info "SET: #{client.owner} - units set to #{client.owner.units}"
          when 'maps' then
            changed = v && client.owner.maps != v
            client.owner.update_attributes!(maps: v) unless v.nil?
            client.say(channel: data.channel, text: "Maps for team #{client.owner.name} are#{changed ? ' now' : ''} *#{client.owner.maps_s}*.")
            logger.info "SET: #{client.owner} - maps set to #{client.owner.maps}"
          else
            raise "Invalid setting #{k}, type `help` for instructions."
          end
        end
      end
    end
  end
end
