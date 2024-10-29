class Team
  field :api, type: Boolean, default: false

  field :units, type: String, default: 'mi'
  validates_inclusion_of :units, in: %w[mi km both]

  field :activity_fields, type: Array, default: ['Default']
  validates :activity_fields, array: { presence: true, inclusion: { in: ActivityFields.values } }

  field :proxy_maps, type: Boolean, default: false
  field :maps, type: String, default: 'full'
  validates_inclusion_of :maps, in: MapTypes.values

  field :stripe_customer_id, type: String
  field :subscribed, type: Boolean, default: false
  field :subscribed_at, type: DateTime
  field :subscription_expired_at, type: DateTime

  field :trial_informed_at, type: DateTime

  scope :api, -> { where(api: true) }
  scope :striped, -> { where(subscribed: true, :stripe_customer_id.ne => nil) }
  scope :trials, -> { where(subscribed: false) }

  has_many :users, dependent: :destroy
  has_many :clubs, dependent: :destroy
  has_many :activities

  before_validation :update_subscribed_at
  before_validation :update_subscription_expired_at
  after_update :subscribed!
  after_save :activated!
  before_destroy :destroy_subscribed_team

  def tags
    [
      subscribed? ? 'subscribed' : 'trial',
      stripe_customer_id? ? 'paid' : nil
    ].compact
  end

  def units_s
    case units
    when 'mi'
      'miles, feet, yards, and degrees Fahrenheit'
    when 'km'
      'kilometers, meters, and degrees Celcius'
    when 'both'
      'both units'
    else
      raise ArgumentError
    end
  end

  def maps_s
    case maps
    when 'off'
      'not displayed'
    when 'full'
      'displayed in full'
    when 'thumb'
      'displayed as thumbnails'
    else
      raise ArgumentError
    end
  end

  def activity_fields_s
    case activity_fields
    when ['All']
      'all displayed if available'
    when ['Default']
      'set to default'
    when ['None']
      'not displayed'
    else
      activity_fields.and
    end
  end

  def asleep?(dt = 2.weeks)
    return false unless subscription_expired?

    time_limit = Time.now - dt
    created_at <= time_limit
  end

  def slack_client
    @slack_client ||= Slack::Web::Client.new(token: token)
  end

  def activated_user_slack_client
    @activated_user_slack_client ||= Slack::Web::Client.new(token: activated_user_access_token)
  end

  def slack_channels
    raise 'missing bot_user_id' unless bot_user_id

    channels = []
    slack_client.users_conversations(
      user: bot_user_id,
      exclude_archived: true,
      types: 'public_channel,private_channel'
    ) do |response|
      channels.concat(response.channels)
    end
    channels
  end

  def bot_in_channel?(channel_id)
    slack_client.conversations_members(channel: channel_id) do |response|
      return true if response.members.include?(bot_user_id)
    end
    false
  end

  def activated_user
    return unless activated_user_id

    users.where(user_id: activated_user_id).first
  end

  def admins
    User.and(
      users.selector,
      User.any_of({ is_admin: true }, { is_owner: true }, { user_id: activated_user_id }).selector
    )
  end

  # returns channels that were sent to
  def inform!(message)
    slack_channels.map do |channel|
      message_with_channel = message.merge(channel: channel['id'], as_user: true)
      logger.info "Posting '#{message_with_channel.to_json}' to #{self} on ##{channel['name']}."
      rc = slack_client.chat_postMessage(message_with_channel)

      {
        ts: rc['ts'],
        channel: channel['id']
      }
    end
  end

  # returns DM channel
  def inform_admin!(message)
    return unless activated_user_id

    channel = slack_client.conversations_open(users: activated_user_id.to_s)
    message_with_channel = message.merge(channel: channel.channel.id, as_user: true)
    logger.info "Sending DM '#{message_with_channel.to_json}' to #{activated_user_id}."
    rc = slack_client.chat_postMessage(message_with_channel)

    {
      ts: rc['ts'],
      channel: channel.channel.id
    }
  end

  def inform_everyone!(message)
    inform!(message)
    inform_admin!(message)
  end

  def subscription_expired!
    return unless subscription_expired?
    return if subscription_expired_at

    inform_everyone!(text: subscribe_text)
    update_attributes!(subscription_expired_at: Time.now.utc)
  end

  def subscription_expired?
    return false if subscribed?

    time_limit = Time.now - 2.weeks
    created_at < time_limit
  end

  def update_cc_text
    "Update your credit card info at #{SlackRubyBotServer::Service.url}/update_cc?team_id=#{team_id}."
  end

  def subscribed_text
    <<~EOS.freeze
      Your team has been subscribed. All proceeds go to NYRR. Thank you!
      Follow https://twitter.com/playplayio for news and updates.
    EOS
  end

  def clubs_to_slack
    result = {
      text: "To connect a club, invite #{bot_mention} to a channel and use `/slava clubs`.",
      attachments: []
    }

    if clubs.any?
      clubs.each do |club|
        attachments = club.to_slack[:attachments]
        attachments.each do |a|
          a[:text] = [a[:text], club.channel_mention].compact.join("\n")
        end
        result[:attachments].concat(attachments)
      end
    else
      result[:text] = 'No clubs connected. ' + result[:text]
    end
    result
  end

  def trial_ends_at
    raise 'Team is subscribed.' if subscribed?

    created_at + 2.weeks
  end

  def remaining_trial_days
    raise 'Team is subscribed.' if subscribed?

    [0, (trial_ends_at.to_date - Time.now.utc.to_date).to_i].max
  end

  def trial_message
    [
      remaining_trial_days.zero? ? 'Your trial subscription has expired.' : "Your trial subscription expires in #{remaining_trial_days} day#{remaining_trial_days == 1 ? '' : 's'}.",
      subscribe_text
    ].join(' ')
  end

  def inform_trial!
    return if subscribed? || subscription_expired?
    return if trial_informed_at && (Time.now.utc < trial_informed_at + 7.days)

    inform_everyone!(text: trial_message)
    update_attributes!(trial_informed_at: Time.now.utc)
  end

  def stripe_customer
    return unless stripe_customer_id

    @stripe_customer ||= Stripe::Customer.retrieve(stripe_customer_id)
  end

  def stripe_customer_text
    "Customer since #{Time.at(stripe_customer.created).strftime('%B %d, %Y')}."
  end

  def stripe_subcriptions
    return unless stripe_customer

    stripe_customer.subscriptions
  end

  def subscriber_text
    return unless subscribed_at

    "Subscriber since #{subscribed_at.strftime('%B %d, %Y')}."
  end

  def subscribe_text
    "Subscribe your team for $9.99 a year at #{SlackRubyBotServer::Service.url}/subscribe?team_id=#{team_id} to continue receiving Strava activities in Slack. All proceeds go to NYRR."
  end

  def stripe_customer_subscriptions_info(with_unsubscribe = false)
    stripe_customer.subscriptions.map do |subscription|
      amount = ActiveSupport::NumberHelper.number_to_currency(subscription.plan.amount.to_f / 100)
      current_period_end = Time.at(subscription.current_period_end).strftime('%B %d, %Y')
      if subscription.status == 'active'
        [
          "Subscribed to #{subscription.plan.name} (#{amount}), will#{subscription.cancel_at_period_end ? ' not' : ''} auto-renew on #{current_period_end}.",
          if with_unsubscribe
            (
                      if subscription.cancel_at_period_end
                        "Send `resubscribe #{subscription.id}` to resubscribe."
                      else
                        "Send `unsubscribe #{subscription.id}` to unsubscribe."
                      end
                    )
          end
        ].compact.join("\n")
      else
        "#{subscription.status.titleize} subscription created #{Time.at(subscription.created).strftime('%B %d, %Y')} to #{subscription.plan.name} (#{amount})."
      end
    end
  end

  def stripe_customer_invoices_info
    stripe_customer.invoices.map do |invoice|
      amount = ActiveSupport::NumberHelper.number_to_currency(invoice.amount_due.to_f / 100)
      "Invoice for #{amount} on #{Time.at(invoice.date).strftime('%B %d, %Y')}, #{invoice.paid ? 'paid' : 'unpaid'}."
    end
  end

  def stripe_customer_sources_info
    stripe_customer.sources.map do |source|
      case source.object
      when 'card'
        "On file #{source.brand} #{source.object}, #{source.name} ending with #{source.last4}, expires #{source.exp_month}/#{source.exp_year}."
      when 'bank_account'
        "On file a bank account #{source.bank_name}, account number #{source.account_number}."
      when 'source'
        "Payment source registered (#{source.type})."
      else
        "On file a payment source I don't understand (#{source.object})."
      end
    end
  end

  def subscription_info(is_admin = true)
    subscription_info = []
    if stripe_subcriptions&.any?
      subscription_info << stripe_customer_text
      subscription_info.concat(stripe_customer_subscriptions_info)
      if is_admin
        subscription_info.concat(stripe_customer_invoices_info)
        subscription_info.concat(stripe_customer_sources_info)
        subscription_info << update_cc_text
      end
    elsif subscribed && subscribed_at
      subscription_info << subscriber_text
    else
      subscription_info << trial_message
    end
    subscription_info.compact.join("\n")
  end

  def active_stripe_subscription?
    !active_stripe_subscription.nil?
  end

  def active_stripe_subscription
    return unless stripe_customer

    stripe_customer.subscriptions.detect do |subscription|
      subscription.status == 'active'
    end
  end

  def ping_if_active!
    return unless active?

    ping!
  rescue Slack::Web::Api::Errors::SlackError => e
    logger.warn "Active team #{self} ping, #{e.message}."
    case e.message
    when 'account_inactive', 'invalid_auth'
      logger.warn "Active team #{self} ping failed auth, deactivating."
      deactivate!
    end
    NewRelic::Agent.notice_error(e, custom_params: { team: to_s })
  end

  def stats(options = {})
    TeamStats.new(self, options)
  end

  def leaderboard(options = {})
    TeamLeaderboard.new(self, options)
  end

  private

  def destroy_subscribed_team
    raise 'cannot destroy a subscribed team' if subscribed?
  end

  def subscribed!
    return unless subscribed? && (subscribed_changed? || saved_change_to_subscribed?)

    inform_everyone!(text: subscribed_text)
  end

  def bot_mention
    "<@#{bot_user_id || 'slava'}>"
  end

  def activated_text
    <<~EOS
      Welcome to Slava!
      Invite #{bot_mention} to a channel to publish activities to it.
      Type "*connect*" to connect your Strava account."
    EOS
  end

  def activated!
    return unless active? && activated_user_id && bot_user_id
    return unless active_changed? || activated_user_id_changed? || saved_change_to_active? || saved_change_to_activated_user_id?

    inform_activated!
  end

  def inform_activated!
    im = slack_client.conversations_open(users: activated_user_id.to_s)
    slack_client.chat_postMessage(
      text: activated_text,
      channel: im['channel']['id'],
      as_user: true
    )
  end

  def update_subscribed_at
    return unless subscribed? && (subscribed_changed? || saved_change_to_subscribed?)

    self.subscribed_at = subscribed? ? DateTime.now.utc : nil
  end

  def update_subscription_expired_at
    return unless subscribed? && subscription_expired_at?

    self.subscription_expired_at = nil
  end
end
