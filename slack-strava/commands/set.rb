module SlackStrava
  module Commands
    class Set < SlackRubyBot::Commands::Base
      include SlackStrava::Commands::Mixins::Subscribe

      subscribe_command 'set' do |client, data, match|
        user = ::User.find_create_or_update_by_slack_id!(client, data.user)
        team = client.owner
        if !match['expression']
          messages = [
            "Activities for team #{team.name} display *#{team.units_s}*.",
            "Activity fields are *#{team.activity_fields_s}*.",
            "Maps for team #{team.name} are *#{team.maps_s}*.",
            "Your private activities will #{user.private_activities? ? '' : 'not'} be posted."
          ]
          client.say(channel: data.channel, text: messages.join("\n"))
          logger.info "SET: #{team}, user=#{data.user} - set"
        else
          k, v = match['expression'].split(/\W+/, 2)
          case k
          when 'private' then
            changed = v && user.private_activities != v
            user.update_attributes!(private_activities: v) unless v.nil?
            client.say(channel: data.channel, text: "Your private activities will#{changed ? (user.private_activities? ? ' now' : ' no longer') : (user.private_activities? ? '' : ' not')} be posted.")
            logger.info "SET: #{team}, user=#{data.user} - private set to #{user.private_activities}"
          when 'units' then
            changed = v && team.units != v
            team.update_attributes!(units: v) unless v.nil?
            client.say(channel: data.channel, text: "Activities for team #{team.name}#{changed ? ' now' : ''} display *#{team.units_s}*.")
            logger.info "SET: #{team} - units set to #{team.units}"
          when 'fields' then
            parsed_fields = ActivityFields.parse_s(v) if v
            changed = v && team.activity_fields != parsed_fields
            team.update_attributes!(activity_fields: parsed_fields) if parsed_fields && parsed_fields.any?
            client.say(channel: data.channel, text: "Activity fields for team #{team.name} are#{changed ? ' now' : ''} *#{team.activity_fields_s}*.")
            logger.info "SET: #{team} - activity fields set to #{team.activity_fields.and}"
          when 'maps' then
            changed = v && team.maps != v
            team.update_attributes!(maps: v) unless v.nil?
            client.say(channel: data.channel, text: "Maps for team #{team.name} are#{changed ? ' now' : ''} *#{team.maps_s}*.")
            logger.info "SET: #{team} - maps set to #{team.maps}"
          else
            raise "Invalid setting #{k}, type `help` for instructions."
          end
        end
      end
    end
  end
end
