module SlackStrava
  module Commands
    class Set < SlackRubyBot::Commands::Base
      include SlackStrava::Commands::Mixins::Subscribe

      subscribe_command 'set' do |client, data, match|
        if !match['expression']
          client.say(channel: data.channel, text: 'Missing setting, eg. _set units km_.', gif: 'help')
          logger.info "SET: #{client.owner} - failed, missing setting"
        else
          k, v = match['expression'].split(/\W+/, 2)
          case k
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
            raise "Invalid setting #{k}, you can _set units km|mi_ or _set maps off|image|thumb_."
          end
        end
      end
    end
  end
end
