module SlackStrava
  module Commands
    class Clubs < SlackRubyBot::Commands::Base
      include SlackStrava::Commands::Mixins::Subscribe

      subscribe_command 'clubs' do |client, data, _match|
        logger.info "CLUBS: #{client.owner}, user=#{data.user}"
        user = ::User.find_create_or_update_by_slack_id!(client, data.user)
        if data.channel[0] == 'D'
          clubs = Club.where(team: user.team)
          if clubs.any?
            clubs.each do |club|
              client.web_client.chat_postMessage(
                club.to_slack.merge(
                  as_user: true,
                  channel: data.channel
                ).tap { |msg|
                  msg[:attachments][0][:text] += "\nConnected to <##{club.channel_id}>."
                }
              )
            end
          else
            client.say(text: 'No clubs currently connected.', as_user: true, channel: data.channel)
          end
        else
          clubs = Club.where(team: user.team, channel_id: data.channel).to_a
          if user.connected_to_strava?
            user.strava_client.paginate(:list_athlete_clubs) do |row|
              strava_id = row['id'].to_s
              next if clubs.detect { |club| club.strava_id == strava_id }
              clubs << Club.new(Club.attrs_from_strava(row).merge(team: user.team))
            end
          end
          clubs.each do |club|
            client.web_client.chat_postEphemeral(
              club.connect_to_slack.merge(
                text: '',
                user: data.user,
                as_user: true,
                channel: data.channel
              )
            )
          end
        end
      end
    end
  end
end
