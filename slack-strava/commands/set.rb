module SlackStrava
  module Commands
    class Set < SlackRubyBot::Commands::Base
      include SlackStrava::Commands::Mixins::Subscribe

      subscribe_command 'set' do |client, data, match|
        user = ::User.find_create_or_update_by_slack_id!(client, data.user)
        team = client.owner
        if match['expression']
          k, v = match['expression'].split(/\W+/, 2)
          case k
          when 'sync'
            changed = v && user.sync_activities != v
            user.update_attributes!(sync_activities: v) unless v.nil?
            client.say(channel: data.channel, text: "Your activities will#{changed ? (user.sync_activities? ? ' now' : ' no longer') : (user.sync_activities? ? '' : ' not')} sync.")
            logger.info "SET: #{team}, user=#{data.user} - sync set to #{user.sync_activities}"
          when 'private'
            changed = v && user.private_activities != v
            user.update_attributes!(private_activities: v) unless v.nil?
            client.say(channel: data.channel, text: "Your private activities will#{changed ? (user.private_activities? ? ' now' : ' no longer') : (user.private_activities? ? '' : ' not')} be posted.")
            logger.info "SET: #{team}, user=#{data.user} - private set to #{user.private_activities}"
          when 'followers'
            changed = v && user.followers_only_activities != v
            user.update_attributes!(followers_only_activities: v) unless v.nil?
            client.say(channel: data.channel, text: "Your followers only activities will#{changed ? (user.followers_only_activities? ? ' now' : ' no longer') : (user.followers_only_activities? ? '' : ' not')} be posted.")
            logger.info "SET: #{team}, user=#{data.user} - followers_only set to #{user.followers_only_activities}"
          when 'units'
            case v
            when 'metric'
              v = 'km'
            when 'imperial'
              v = 'mi'
            end
            changed = v && team.units != v
            if !user.team_admin? && changed
              client.say(channel: data.channel, text: "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change units. Activities for team #{team.name} display *#{team.units_s}*.")
              logger.info "SET: #{team} - not admin, units remain set to #{team.units}"
            else
              team.update_attributes!(units: v) unless v.nil?
              client.say(channel: data.channel, text: "Activities for team #{team.name}#{changed ? ' now' : ''} display *#{team.units_s}*.")
              logger.info "SET: #{team} - units set to #{team.units}"
            end
          when 'fields'
            parsed_fields = ActivityFields.parse_s(v) if v
            changed = parsed_fields && team.activity_fields != parsed_fields
            if !user.team_admin? && changed
              client.say(channel: data.channel, text: "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change fields. Activity fields for team #{team.name} are *#{team.activity_fields_s}*.")
              logger.info "SET: #{team} - not admin, activity fields remain set to #{team.activity_fields.and}"
            else
              team.update_attributes!(activity_fields: parsed_fields) if changed && parsed_fields&.any?
              client.say(channel: data.channel, text: "Activity fields for team #{team.name} are#{changed ? ' now' : ''} *#{team.activity_fields_s}*.")
              logger.info "SET: #{team} - activity fields set to #{team.activity_fields.and}"
            end
          when 'maps'
            parsed_value = MapTypes.parse_s(v) if v
            changed = parsed_value && team.maps != parsed_value
            if !user.team_admin? && changed
              client.say(channel: data.channel, text: "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change maps. Maps for team #{team.name} are *#{team.maps_s}*.")
              logger.info "SET: #{team} - not admin, maps remain set to #{team.maps}"
            else
              team.update_attributes!(maps: parsed_value) if parsed_value
              client.say(channel: data.channel, text: "Maps for team #{team.name} are#{changed ? ' now' : ''} *#{team.maps_s}*.")
              logger.info "SET: #{team} - maps set to #{team.maps}"
            end
          when 'leaderboard'
            changed = v && team.default_leaderboard != v
            if !user.team_admin? && changed
              client.say(channel: data.channel, text: "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change the default leaderboard. Default leaderboard for team #{team.name} is *#{team.default_leaderboard_s}*.")
              logger.info "SET: #{team} - not admin, default leaderboard remain set to #{team.default_leaderboard}"
            else
              team.update_attributes!(default_leaderboard: v) if Leaderboard.parse_expression(v) && changed
              client.say(channel: data.channel, text: "Default leaderboard for team #{team.name} is#{changed ? ' now' : ''} *#{team.default_leaderboard_s}*.")
              logger.info "SET: #{team} - default leaderboard set to #{team.default_leaderboard}"
            end
          when 'retention'
            v = ChronicDuration.parse(v) if v
            changed = v && team.retention != v
            if !user.team_admin? && changed
              client.say(channel: data.channel, text: "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change activity retention. Activities in team #{team.name} are retained for *#{team.retention_s}*.")
              logger.info "SET: #{team} - not admin, default activity retention remains set to #{team.retention}"
            else
              team.update_attributes!(retention: v) if changed
              client.say(channel: data.channel, text: "Activities in team #{team.name} are#{changed ? ' now' : ''} retained for *#{team.retention_s}*.")
              logger.info "SET: #{team} - activity retention set to #{team.retention} (#{team.retention_s})"
            end
          else
            raise "Invalid setting #{k}, type `help` for instructions."
          end
        else
          messages = [
            "Activities for team #{team.name} display *#{team.units_s}*.",
            "Activities are retained for *#{team.retention_s}*.",
            "Activity fields are *#{team.activity_fields_s}*.",
            "Maps are *#{team.maps_s}*.",
            "Default leaderboard is *#{team.default_leaderboard_s}*.",
            "Your activities will #{user.sync_activities? ? '' : 'not '}sync.",
            "Your private activities will #{user.private_activities? ? '' : 'not '}be posted.",
            "Your followers only activities will #{user.followers_only_activities? ? '' : 'not '}be posted."
          ]
          client.say(channel: data.channel, text: messages.join("\n"))
          logger.info "SET: #{team}, user=#{data.user} - set"
        end
      end
    end
  end
end
