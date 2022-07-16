module SlackStrava
  module Commands
    class Help < SlackRubyBot::Commands::Base
      HELP = <<~EOS.freeze
        ```
        I am your friendly bot powered by Strava.

        DM or /slava
        ------------
        connect                          - connect your Strava account
        disconnect                       - disconnect your Strava account

        Clubs
        ------------
        /slava clubs                     - connect/disconnect clubs

        Teams
        ------------
        stats                            - stats in current channel for the past 30 days

        Settings
        ------------
        set units imperial|metric|both   - use imperial vs. metric units, or display both
        set fields all|none|...          - display all, none or certain activity fields
        set maps off|full|thumb          - change the way maps are displayed
        set sync true|false              - sync activities (default is true)
        set private true|false           - sync private (only you) activities (default is false)
        set followers true|false         - sync followers only activities (default is true)

        General
        ------------
        help                             - get this helpful message
        subscription                     - show subscription info, update credit-card
        unsubscribe                      - turn off subscription auto-renew
        info                             - bot info, contact, feature requests
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
