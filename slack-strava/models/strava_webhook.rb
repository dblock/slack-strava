class StravaWebhook
  def self.instance
    @instance ||= new
  end

  def client
    @client ||= Strava::Webhooks::Client.new(
      client_id: ENV['STRAVA_CLIENT_ID'],
      client_secret: ENV['STRAVA_CLIENT_SECRET']
    )
  end

  def callback_url
    "#{SlackRubyBotServer::Service.url}/api/strava/event"
  end

  def subscription
    @subscription ||= client.push_subscriptions.detect do |s|
      s.callback_url == callback_url
    end
  end

  def subscribed?
    subscription.present?
  end

  def verify_token
    Digest::MD5.hexdigest(ENV['STRAVA_CLIENT_SECRET'])
  end

  def subscribe!
    Api::Middleware.logger.info "Creating a Strava webhook subscription at #{callback_url} ..."
    @subscription = client.create_push_subscription(
      callback_url: callback_url,
      verify_token: verify_token
    )
  end

  def unsubscribe!
    Api::Middleware.logger.info "Deleting a Strava webhook subscription #{subscription.id} at #{callback_url} ..."
    client.delete_push_subscription(id: subscription.id)
    @subscription = nil
  end

  def list!
    client.push_subscriptions.each do |s|
      Api::Middleware.logger.info "Seeing an existing Strava webhook subscription #{s.id} at #{s.callback_url}."
    end
  end

  def ensure!
    list!
    # unsubscribe! if subscribed?
    subscribe! unless subscribed?
    Api::Middleware.logger.info "Using Strava webhook subscription #{subscription.id} at #{subscription.callback_url || callback_url}."
  end
end
