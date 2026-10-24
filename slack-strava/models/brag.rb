module Brag
  def with_strava_error_handler(&_block)
    return unless team.reload.active?

    yield
  rescue Strava::Errors::RatelimitError => e
    logger.warn 'Strava API rate limit exceeded.'
    NewRelic::Agent.notice_error(e, custom_params: { team: team.to_s, response: { body: e.response[:body] }, self: to_s })
    raise e
  rescue Slack::Web::Api::Errors::SlackError => e
    if e.message == 'account_inactive'
      team.deactivate_for_inactive_account!(e)
    else
      backtrace = e.backtrace.join("\n")
      logger.warn "Error in team #{team}, #{self}, #{e.message}, #{e.response.body}, #{backtrace}."
      NewRelic::Agent.notice_error(e, custom_params: { team: team.to_s, response: { body: e.response.body }, self: to_s })
    end
  rescue Strava::Errors::Fault, Faraday::Error => e
    backtrace = e.backtrace.join("\n")
    logger.warn "Error in team #{team}, #{self}, #{e.message}, #{e.response[:body]}, #{backtrace}."
    NewRelic::Agent.notice_error(e, custom_params: { team: team.to_s, response: { body: e.response[:body] }, self: to_s })
  rescue StandardError => e
    backtrace = e.backtrace.join("\n")
    logger.warn "Error in team #{team}, #{self}, #{e.message}, #{backtrace}."
    NewRelic::Agent.notice_error(e, custom_params: { team: team.to_s, self: to_s })
  end

  def sync_and_brag!
    with_lock do
      with_strava_error_handler do
        sync_new_strava_activities!
        brag!
      end
    end
  end
end
