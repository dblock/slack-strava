module SlackStrava
  module Commands
    class Help < SlackRubyBot::Commands::Base
      HELP = <<~EOS.freeze
        ```
        I am your friendly bot powered by Strava.

        DM or /slava
        ------------
        connect                  - connect your Strava account
        disconnect               - disconnect your Strava account

        Clubs
        ------------
        /slava clubs             - connect/disconnect clubs

        Settings
        ------------
        set units mi|km          - use miles or kilometers
        set fields all|none|...  - display all, none or certain activity fields
        set maps off|full|thumb  - change the way maps are displayed
        set sync true|false      - sync activities (default is true)
        set private true|false   - sync private activities (default is false)

        General
        ------------
        help                     - get this helpful message
        subscription             - show subscription info
        unsubscribe              - turn off subscription auto-renew
        info                     - bot info
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
