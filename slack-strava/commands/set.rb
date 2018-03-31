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
            client.say(channel: data.channel, text: "Activities for team #{client.owner.name}#{changed ? ' now' : ''} display *#{client.owner.units_s}*.", gif: 'units')
            logger.info "SET: #{client.owner} - units set to #{client.owner.units}"
          else
            raise "Invalid setting #{k}, you can _set units km|mi_."
          end
        end
      end
    end
  end
end
