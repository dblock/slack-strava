class Team
  field :api, type: Boolean, default: false

  field :units, type: String, default: 'mi'
  validates_inclusion_of :units, in: %w[mi km]

  field :stripe_customer_id, type: String
  field :subscribed, type: Boolean, default: false
  field :subscribed_at, type: DateTime
  field :subscription_expired_at, type: DateTime
  field :bot_user_id, type: String
  field :activated_user_id, type: String

  scope :api, -> { where(api: true) }
  scope :striped, -> { where(subscribed: true, :stripe_customer_id.ne => nil) }

  has_many :users, dependent: :destroy

  before_validation :update_subscription_expired_at
  after_update :inform_subscribed_changed!
  after_save :inform_activated!

  def units_s
    case units
    when 'mi'
      'miles'
    when 'km'
      'kilometers'
    else
      raise ArgumentError
    end
  end

  def asleep?(dt = 2.weeks)
    return false unless subscription_expired?
    time_limit = Time.now - dt
    created_at <= time_limit
  end

  # returns channels that were sent to
  def inform!(message, user_id = nil)
    client = Slack::Web::Client.new(token: token)
    channels = client
               .channels_list(exclude_archived: true, exclude_members: true)['channels']
               .select { |channel| channel['is_member'] }
    channels.each do |channel|
      next if user_id && !user_in_channel?(user_id, channel['id'])
      message_with_channel = message.merge(channel: channel['id'], as_user: true)
      logger.info "Posting '#{message_with_channel.to_json}' to #{self} on ##{channel['name']}."
      client.chat_postMessage(message_with_channel)
    end
    channels.map { |channel| "<##{channel['id']}|#{channel['name']}>" }
  end

  def user_in_channel?(user_id, channel_id)
    client = Slack::Web::Client.new(token: token)
    client.conversations_members(channel: channel_id) do |response|
      return true if response.members.include?(user_id)
    end
    false
  end

  def subscription_expired!
    return unless subscription_expired?
    return if subscription_expired_at
    inform!(text: subscribe_text)
    update_attributes!(subscription_expired_at: Time.now.utc)
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

  def subscribed_text
    <<~EOS.freeze
      Your team has been subscribed. All proceeds go to NYC TeamForKids charity. Thank you!
      Follow https://twitter.com/playplayio for news and updates.
EOS
  end

  private

  def trial_expired_text
    return unless subscription_expired?
    'Your trial subscription has expired.'
  end

  def subscribe_team_text
    "Subscribe your team for $29.99 a year at #{SlackStrava::Service.url}/subscribe?team_id=#{team_id} to continue receiving Strava activities in Slack. All proceeds donated to NYC TeamForKids charity."
  end

  def inform_subscribed_changed!
    return unless subscribed? && subscribed_changed?
    inform!(text: subscribed_text)
  end

  def activated_text
    <<~EOS
      Welcome to Slava!
      Invite <@#{bot_user_id}> to a channel to publish activities to it.
      Type \"*connect*\" to connect your Strava account."
EOS
  end

  def inform_activated!
    return unless active? && activated_user_id && bot_user_id
    return unless active_changed? || activated_user_id_changed?
    client = Slack::Web::Client.new(token: token)
    im = client.im_open(user: activated_user_id)
    client.chat_postMessage(
      text: activated_text,
      channel: im['channel']['id'],
      as_user: true
    )
  end

  def update_subscription_expired_at
    self.subscription_expired_at = nil if subscribed || subscribed_at
  end
end
