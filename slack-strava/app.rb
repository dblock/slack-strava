module SlackStrava
  class App < SlackRubyBotServer::App
    def after_start!
      ::Async::Reactor.run do
        logger.info 'Starting crons.'
        once_and_every 60 * 60 * 24 do
          check_subscribed_teams!
          deactivate_asleep_teams!
          check_trials!
          prune_pngs!
        end
        once_and_every 60 * 60 do
          expire_subscriptions!
        end
        once_and_every 30 * 60 do
          brag!
        end
        once_and_every 3 * 60 * 60 do
          rebrag!
        end
      end
    end

    private

    def log_info_without_repeat(message)
      return if message == @log_message

      @log_message = message
      logger.info message
    end

    def once_and_every(tt)
      ::Async::Reactor.run do |task|
        loop do
          yield
          task.sleep tt
        end
      end
    end

    def check_trials!
      log_info_without_repeat "Checking trials for #{Team.active.trials.count} team(s)."
      Team.active.trials.each do |team|
        logger.info "Team #{team} has #{team.remaining_trial_days} trial days left."
        unless team.remaining_trial_days > 0 && team.remaining_trial_days <= 3
          next
        end

        team.inform_trial!
      rescue StandardError => e
        logger.warn "Error checking team #{team} trial, #{e.message}."
      end
    end

    def prune_pngs!
      activities = UserActivity.where(
        'map.png_retrieved_at' => {
          '$lt' => Time.now - 2.weeks
        },
        'map.png' => { '$ne' => nil }
      )
      log_info_without_repeat "Pruning #{activities.count} PNGs for #{Team.active.trials.count} team(s)."
      activities.each do |activity|
        activity.map.delete_png!
      end
    end

    def expire_subscriptions!
      log_info_without_repeat "Checking subscriptions for #{Team.active.count} team(s)."
      Team.active.each do |team|
        next unless team.subscription_expired?

        team.subscription_expired!
      rescue StandardError => e
        backtrace = e.backtrace.join("\n")
        logger.warn "Error in expire subscriptions cron for team #{team}, #{e.message}, #{backtrace}."
      end
    end

    def brag!
      log_info_without_repeat "Checking activities for #{Team.active.count} team(s)."
      Team.active.each do |team|
        next if team.subscription_expired?

        begin
          team.users.connected_to_strava.each(&:sync_and_brag!)
          team.clubs.connected_to_strava.each(&:sync_and_brag!)
        rescue StandardError => e
          backtrace = e.backtrace.join("\n")
          logger.warn "Error in brag cron for team #{team}, #{e.message}, #{backtrace}."
        end
      end
    end

    def rebrag!
      log_info_without_repeat "Editing activities for #{Team.active.count} team(s)."
      Team.active.each do |team|
        next if team.subscription_expired?

        begin
          team.users.connected_to_strava.each(&:rebrag!)
        rescue StandardError => e
          backtrace = e.backtrace.join("\n")
          logger.warn "Error in rebrag cron for team #{team}, #{e.message}, #{backtrace}."
        end
      end
    end

    def deactivate_asleep_teams!
      log_info_without_repeat "Checking inactivity for #{Team.active.count} team(s)."
      Team.active.each do |team|
        next unless team.asleep?

        begin
          team.deactivate!
          purge_message = "Your subscription expired more than 2 weeks ago, deactivating. Reactivate at #{SlackRubyBotServer::Service.url}. Your data will be purged in another 2 weeks."
          team.inform_everyone!(text: purge_message)
        rescue StandardError => e
          logger.warn "Error informing team #{team}, #{e.message}."
        end
      end
    end

    def check_subscribed_teams!
      logger.info "Checking Stripe subscriptions for #{Team.striped.count} team(s)."
      Team.striped.each do |team|
        customer = Stripe::Customer.retrieve(team.stripe_customer_id)
        customer.subscriptions.each do |subscription|
          subscription_name = "#{subscription.plan.name} (#{ActiveSupport::NumberHelper.number_to_currency(subscription.plan.amount.to_f / 100)})"
          logger.info "Checking #{team} subscription to #{subscription_name}, #{subscription.status}."
          case subscription.status
          when 'past_due'
            logger.warn "Subscription for #{team} is #{subscription.status}, notifying."
            team.inform_everyone!(text: "Your subscription to #{subscription_name} is past due. #{team.update_cc_text}")
          when 'canceled', 'unpaid'
            logger.warn "Subscription for #{team} is #{subscription.status}, downgrading."
            team.inform_everyone!(text: "Your subscription to #{subscription.plan.name} (#{ActiveSupport::NumberHelper.number_to_currency(subscription.plan.amount.to_f / 100)}) was canceled and your team has been downgraded. Thank you for being a customer!")
            team.update_attributes!(subscribed: false)
          end
        end
      rescue StandardError => e
        logger.warn "Error checking team #{team} subscription, #{e.message}."
      end
    end
  end
end
