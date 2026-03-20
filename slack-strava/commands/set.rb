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
            if data.channel.start_with?('C')
              channel_info = team.slack_client.conversations_info(channel: data.channel).channel
              channel_name = channel_info['name']
              if v
                uc = user.set_user_channel!(data.channel, channel_name, sync_activities: v)
                changed = true
              else
                uc = user.user_channels.find_by(channel_id: data.channel)
              end
              effective = user.sync_activities_for_channel?(data.channel)
              if changed
                client.say(channel: data.channel, text: "Your activities will#{effective ? ' now' : ' no longer'} sync in <##{data.channel}>.")
              else
                client.say(channel: data.channel, text: "Your activities will#{' not' unless effective} sync in <##{data.channel}>.")
              end
              logger.info "SET: #{team}, user=#{data.user} - sync in #{data.channel} set to #{uc&.sync_activities.inspect}"
            else
              changed = v && user.sync_activities != v
              user.update_attributes!(sync_activities: v) unless v.nil?
              client.say(channel: data.channel, text: "Your activities will#{changed ? (user.sync_activities? ? ' now' : ' no longer') : (user.sync_activities? ? '' : ' not')} sync.")
              logger.info "SET: #{team}, user=#{data.user} - sync set to #{user.sync_activities}"
            end
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
              client.say(channel: data.channel, text: "Activities for team #{team.name}#{' now' if changed} display *#{team.units_s}*.")
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
              client.say(channel: data.channel, text: "Activity fields for team #{team.name} are#{' now' if changed} *#{team.activity_fields_s}*.")
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
              client.say(channel: data.channel, text: "Maps for team #{team.name} are#{' now' if changed} *#{team.maps_s}*.")
              logger.info "SET: #{team} - maps set to #{team.maps}"
            end
          when 'threads'
            parsed_value = ThreadTypes.parse_s(v) if v
            changed = parsed_value && team.threads != parsed_value
            if !user.team_admin? && changed
              client.say(channel: data.channel, text: "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change whether activities roll up in threads. Activities for team #{team.name} are *#{team.threads_s}*.")
              logger.info "SET: #{team} - not admin, threads remain set to #{team.threads}"
            else
              team.update_attributes!(threads: parsed_value) if parsed_value
              client.say(channel: data.channel, text: "Activities for team #{team.name} are#{' now' if changed} *#{team.threads_s}*.")
              logger.info "SET: #{team} - threads set to #{team.threads}"
            end
          when 'leaderboard'
            changed = v && team.default_leaderboard != v
            if !user.team_admin? && changed
              client.say(channel: data.channel, text: "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change the default leaderboard. Default leaderboard for team #{team.name} is *#{team.default_leaderboard_s}*.")
              logger.info "SET: #{team} - not admin, default leaderboard remain set to #{team.default_leaderboard}"
            else
              team.update_attributes!(default_leaderboard: v) if Leaderboard.parse_expression(v) && changed
              client.say(channel: data.channel, text: "Default leaderboard for team #{team.name} is#{' now' if changed} *#{team.default_leaderboard_s}*.")
              logger.info "SET: #{team} - default leaderboard set to #{team.default_leaderboard}"
            end
          when 'timezone'
            if v == 'auto'
              new_timezone = 'auto'
            elsif v
              tz = ActiveSupport::TimeZone.new(v)
              raise SlackStrava::Error, "TimeZone _#{v}_ is invalid, see https://github.com/rails/rails/blob/v#{ActiveSupport.gem_version}/activesupport/lib/active_support/values/time_zone.rb#L30 for a list. Timezone for team #{team.name} is currently *#{team.timezone_s}*." unless tz

              new_timezone = tz.name
            end
            changed = new_timezone && team.timezone != new_timezone
            if !user.team_admin? && changed
              client.say(channel: data.channel, text: "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change the timezone. Timezone for team #{team.name} is *#{team.timezone_s}*.")
              logger.info "SET: #{team} - not admin, timezone remains set to #{team.timezone}"
            else
              team.update_attributes!(timezone: new_timezone) if changed
              client.say(channel: data.channel, text: "Timezone for team #{team.name} is#{' now' if changed} *#{team.timezone_s}*.")
              logger.info "SET: #{team} - timezone set to #{team.timezone}"
            end
          when 'retention'
            v = ChronicDuration.parse(v) if v
            changed = v && team.retention != v
            if !user.team_admin? && changed
              client.say(channel: data.channel, text: "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change activity retention. Activities in team #{team.name} are retained for *#{team.retention_s}*.")
              logger.info "SET: #{team} - not admin, default activity retention remains set to #{team.retention}"
            else
              team.update_attributes!(retention: v) if changed
              client.say(channel: data.channel, text: "Activities in team #{team.name} are#{' now' if changed} retained for *#{team.retention_s}*.")
              logger.info "SET: #{team} - activity retention set to #{team.retention} (#{team.retention_s})"
            end
          when 'userlimit'
            raw_v = v
            if v
              raise SlackStrava::Error, "Invalid value: #{v}. Please use a positive number or 'none'." unless v =~ /\A(none|\d+)\z/i

              v = v =~ /\Anone\z/i ? nil : v.to_i
            end
            changed = raw_v && team.max_activities_per_user_per_day != v
            if !user.team_admin? && changed
              client.say(channel: data.channel, text: "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change the max activities per user per day. Max activities per user per day for team #{team.name} are *#{team.max_activities_per_user_per_day_s}*.")
              logger.info "SET: #{team} - not admin, max activities per user per day remains set to #{team.max_activities_per_user_per_day}"
            else
              team.update_attributes!(max_activities_per_user_per_day: v) if changed
              client.say(channel: data.channel, text: "Max activities per user per day for team #{team.name} are#{' now' if changed} *#{team.max_activities_per_user_per_day_s}*.")
              logger.info "SET: #{team} - max activities per user per day set to #{team.max_activities_per_user_per_day}"
            end
          when 'activities'
            unless data.channel.start_with?('C')
              client.say(channel: data.channel, text: 'You can only set activity types in a channel, not a DM.')
              return
            end
            channel_info = team.slack_client.conversations_info(channel: data.channel).channel
            channel_name = channel_info['name']
            if v.nil? || v =~ /\Aall\z/i
              new_types = []
              changed = v && !team.channel_activity_types_for(data.channel).empty?
            else
              input_types = v.split(/[\s,]+/).map(&:strip).reject(&:empty?)
              new_types = input_types.map do |t|
                matched = ActivityMethods::ACTIVITY_TYPES.find { |at| at.casecmp(t).zero? }
                unless matched
                  client.say(channel: data.channel, text: "Invalid activity type: #{t}. Use: #{ActivityMethods::ACTIVITY_TYPES.or}.")
                  return
                end
                matched
              end
              changed = team.channel_activity_types_for(data.channel) != new_types
            end
            if !user.team_admin? && changed
              client.say(channel: data.channel, text: "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change activity types for a channel. Activity types for <##{data.channel}> are *#{team.channel_activity_types_s(data.channel)}*.")
              logger.info "SET: #{team} - not admin, activity types for #{data.channel} remain #{team.channel_activity_types_for(data.channel).inspect}"
            else
              team.set_channel!(data.channel, channel_name, activity_types: new_types) if changed
              client.say(channel: data.channel, text: "Activity types for <##{data.channel}> are#{' now' if changed} *#{team.channel_activity_types_s(data.channel)}*.")
              logger.info "SET: #{team} - activity types for #{data.channel} set to #{team.channel_activity_types_for(data.channel).inspect}"
            end
          when 'channellimit'
            raw_v = v
            if v
              raise SlackStrava::Error, "Invalid value: #{v}. Please use a positive number or 'none'." unless v =~ /\A(none|\d+)\z/i

              v = v =~ /\Anone\z/i ? nil : v.to_i
            end
            changed = raw_v && team.max_activities_per_channel_per_day != v
            if !user.team_admin? && changed
              client.say(channel: data.channel, text: "Sorry, only <@#{team.activated_user_id}> or a Slack admin can change the max activities per channel per day. Max activities per channel per day for team #{team.name} are *#{team.max_activities_per_channel_per_day_s}*.")
              logger.info "SET: #{team} - not admin, max activities per channel per day remains set to #{team.max_activities_per_channel_per_day}"
            else
              team.update_attributes!(max_activities_per_channel_per_day: v) if changed
              client.say(channel: data.channel, text: "Max activities per channel per day for team #{team.name} are#{' now' if changed} *#{team.max_activities_per_channel_per_day_s}*.")
              logger.info "SET: #{team} - max activities per channel per day set to #{team.max_activities_per_channel_per_day}"
            end
          else
            raise "Invalid setting #{k}, type `help` for instructions."
          end
        else
          messages = [
            "Activities for team #{team.name} display *#{team.units_s}*.",
            "Activities are *#{team.threads_s}*.",
            "Activities are retained for *#{team.retention_s}*.",
            "Timezone is *#{team.timezone_s}*.",
            "Max activities per user per day are *#{team.max_activities_per_user_per_day_s}*.",
            "Max activities per channel per day are *#{team.max_activities_per_channel_per_day_s}*.",
            "Activity fields are *#{team.activity_fields_s}*.",
            "Maps are *#{team.maps_s}*.",
            "Default leaderboard is *#{team.default_leaderboard_s}*.",
            if data.channel.start_with?('C')
              "Your activities will *#{'not ' unless user.sync_activities_for_channel?(data.channel)}sync* in <##{data.channel}>."
            else
              "Your activities will *#{'not ' unless user.sync_activities?}sync*."
            end,
            data.channel.start_with?('C') ? "Activity types for <##{data.channel}> are *#{team.channel_activity_types_s(data.channel)}*." : nil,
            "Your private activities will *#{'not ' unless user.private_activities?}be posted*.",
            "Your followers only activities will *#{'not ' unless user.followers_only_activities?}be posted*."
          ]
          client.say(channel: data.channel, text: messages.compact.join("\n"))
          logger.info "SET: #{team}, user=#{data.user} - set"
        end
      end
    end
  end
end
