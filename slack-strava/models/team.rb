class Team
  field :api, type: Boolean, default: false

  field :units, type: String, default: 'mi'
  validates_inclusion_of :units, in: %w[mi km]

  field :activity_fields, type: Array, default: ['All']
  validates :activity_fields, array: { presence: true, inclusion: { in: ActivityFields.values } }

  field :maps, type: String, default: 'full'
  validates_inclusion_of :maps, in: MapTypes.values

  field :stripe_customer_id, type: String
  field :subscribed, type: Boolean, default: false
  field :subscribed_at, type: DateTime
  field :subscription_expired_at, type: DateTime
  field :bot_user_id, type: String
  field :activated_user_id, type: String
  field :activated_user_access_token, type: String

  field :trial_informed_at, type: DateTime

  scope :api, -> { where(api: true) }
  scope :striped, -> { where(subscribed: true, :stripe_customer_id.ne => nil) }
  scope :trials, -> { where(subscribed: false) }

  has_many :users, dependent: :destroy
  has_many :clubs, dependent: :destroy

  before_validation :update_subscription_expired_at
  after_update :subscribed!
  after_save :activated!

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

  def maps_s
    case maps
    when 'off' then
      'not displayed'
    when 'full' then
      'displayed in full'
    when 'thumb' then
      'displayed as thumbnails'
    else
      raise ArgumentError
    end
  end

  def activity_fields_s
    case activity_fields
    when ['All'] then
      'displayed as available'
    when ['None'] then
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
    slack_client.channels_list(
      exclude_archived: true,
      exclude_members: true
    )['channels'].select do |channel|
      channel['is_member']
    end
  end

  def bot_in_channel?(channel_id)
    slack_client.conversations_members(channel: channel_id) do |response|
      return true if response.members.include?(bot_user_id)
    end
    false
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
    channel = slack_client.im_open(user: activated_user_id)
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

  def subscribe_text
    [trial_expired_text, subscribe_team_text].compact.join(' ')
  end

  def update_cc_text
    "Update your credit card info at #{SlackStrava::Service.url}/update_cc?team_id=#{team_id}."
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

  def signup_to_mailing_list!
    return unless activated_user_id
    profile ||= Hashie::Mash.new(slack_client.users_info(user: activated_user_id)).user.profile
    return unless profile
    return unless mailchimp_list
    tags = ['slava', subscribed? ? 'subscribed' : 'trial', stripe_customer_id? ? 'paid' : nil].compact
    member = mailchimp_list.members.where(email_address: profile.email).first
    if member
      member_tags = member.tags.map { |tag| tag['name'] }.sort
      tags = (member_tags + tags).uniq
      return if tags == member_tags
    end
    mailchimp_list.members.create_or_update(
      name: profile.name,
      email_address: profile.email,
      unique_email_id: "#{team_id}-#{activated_user_id}",
      status: member ? member.status : 'pending',
      tags: tags,
      merge_fields: {
        'FNAME' => profile.first_name.to_s,
        'LNAME' => profile.last_name.to_s,
        'BOT' => 'Slava'
      }
    )
    logger.info "Subscribed #{profile.email} to #{ENV['MAILCHIMP_LIST_ID']}, #{self}."
  rescue StandardError => e
    logger.error "Error subscribing #{self} to #{ENV['MAILCHIMP_LIST_ID']}: #{e.message}, #{e.errors}"
  end

  private

  def trial_expired_text
    return unless subscription_expired?
    'Your trial subscription has expired.'
  end

  def subscribe_team_text
    "Subscribe your team for $9.99 a year at #{SlackStrava::Service.url}/subscribe?team_id=#{team_id} to continue receiving Strava activities in Slack. All proceeds go to NYRR."
  end

  def subscribed!
    return unless subscribed? && subscribed_changed?
    inform_everyone!(text: subscribed_text)
    signup_to_mailing_list!
  end

  def bot_mention
    "<@#{bot_user_id || 'slava'}>"
  end

  def activated_text
    <<~EOS
      Welcome to Slava!
      Invite #{bot_mention} to a channel to publish activities to it.
      Type \"*connect*\" to connect your Strava account."
EOS
  end

  def activated!
    return unless active? && activated_user_id && bot_user_id
    return unless active_changed? || activated_user_id_changed?
    inform_activated!
    signup_to_mailing_list!
  end

  def inform_activated!
    im = slack_client.im_open(user: activated_user_id)
    slack_client.chat_postMessage(
      text: activated_text,
      channel: im['channel']['id'],
      as_user: true
    )
  end

  def update_subscription_expired_at
    self.subscription_expired_at = nil if subscribed || subscribed_at
  end

  # mailing list management

  def mailchimp_client
    return unless ENV.key?('MAILCHIMP_API_KEY')
    @mailchimp_client ||= Mailchimp.connect(ENV['MAILCHIMP_API_KEY'])
  end

  def mailchimp_list
    return unless mailchimp_client
    rerurn unless ENV.key?('MAILCHIMP_LIST_ID')
    @mailchimp_list ||= mailchimp_client.lists(ENV['MAILCHIMP_LIST_ID'])
  end
end
