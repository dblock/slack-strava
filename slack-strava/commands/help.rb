module SlackStrava
  module Commands
    class Help < SlackRubyBot::Commands::Base
      HELP = <<~EOS.freeze
        ```
        I am your friendly bot powered by Strava.

        DM or /slava
        ------------
        connect                                - connect your Strava account
        disconnect                             - disconnect your Strava account

        Clubs
        ------------
        /slava clubs                           - connect/disconnect clubs

        Teams
        ------------
        stats                                  - stats in current channel
        leaderboard distance|... [when]        - leaderboard by distance, etc.
          2025|last year|[month]|...
          since|between [date] [and [date]]

        Settings
        ------------
        set retention [n] days|months|years    - set how long to retain user activities (default is 30 days)
        set timezone [auto|tz]                 - set timezone, auto-detect from activities (default is auto)
        set threads none|daily|weekly|monthly  - set activity threading (in channel overrides team default)
        set userlimit [n]|none                 - max per user per day (in channel overrides team default)
        set channellimit [n]|none              - max activities posted per channel per day (default is unlimited)
        set units imperial|metric|both         - use imperial vs. metric units (in channel overrides team default)
        set temperature f|c|both               - temperature units, independent of distance units (in channel overrides team default)
        set fields all|none|...                - activity fields displayed (in channel overrides team default)
        set maps off|full|thumb                - map display style (in channel overrides team default)
        set leaderboard elapsed time|...       - change the default leaderboard
        set activities all|run,ride,...        - set activity types posted in this channel (in channel, admin only)
        set sync true|false                    - sync activities globally (in DM) or per channel (in channel)
        set private true|false                 - sync private (only you) activities (default is false)
        set followers true|false               - sync followers only activities (default is true)

        General
        ------------
        help                                   - get this helpful message
        subscription                           - show subscription info, update credit-card
        unsubscribe                            - turn off subscription auto-renew
        resubscribe                            - turn on subscription auto-renew
        info                                   - bot info, contact, feature requests
        ```
      EOS
      def self.call(client, data, _match)
        client.say(channel: data.channel, text: [
          HELP,
          client.owner.reload.subscribed? ? nil : client.owner.trial_message
        ].compact.join("\n"))
        logger.info "HELP: #{client.owner}, user=#{data.user}"
      end
    end
  end
end
