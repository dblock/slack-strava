class Team
  field :api, type: Boolean, default: false

  field :stripe_customer_id, type: String
  field :subscribed, type: Boolean, default: false
  field :subscribed_at, type: DateTime

  scope :api, -> { where(api: true) }

  has_many :users

  after_update :inform_subscribed_changed!

  def asleep?(dt = 2.weeks)
    return false unless subscription_expired?
    time_limit = Time.now - dt
    created_at <= time_limit
  end

  def inform!(message)
    client = Slack::Web::Client.new(token: token)
    channels = client.channels_list['channels'].select { |channel| channel['is_member'] }
    return unless channels.any?
    channel = channels.first
    logger.info "Sending '#{message}' to #{self} on ##{channel['name']}."
    client.chat_postMessage(text: message, channel: channel['id'], as_user: true)
  end

  # returns channels that were sent to
  def brag!(message)
    client = Slack::Web::Client.new(token: token)
    channels = client.channels_list['channels'].select { |channel| channel['is_member'] }
    channels.each do |channel|
      client.chat_postMessage(message.merge(channel: channel['id'], as_user: true))
    end
    channels.map { |channel| "<##{channel['id']}|#{channel['name']}>" }
  end

  def subscription_expired?
    return false if subscribed?
    (created_at + 1.week) < Time.now
  end

  def subscribe_text
    [trial_expired_text, subscribe_team_text].compact.join(' ')
  end

  def update_cc_text
    "Update your credit card info at #{SlackStrava::Service.url}/update_cc?team_id=#{team_id}."
  end

  private

  def trial_expired_text
    return unless subscription_expired?
    'Your trial subscription has expired.'
  end

  def subscribe_team_text
    "Subscribe your team for $29.99 a year at #{SlackStrava::Service.url}/subscribe?team_id=#{team_id}."
  end

  SUBSCRIBED_TEXT = <<~EOS.freeze
    Your team has been subscribed, enjoy all features. Thanks for supporting open-source!
    Follow https://twitter.com/playplayio for news and updates.
EOS

  def inform_subscribed_changed!
    return unless subscribed? && subscribed_changed?
    inform! SUBSCRIBED_TEXT
  end
end
