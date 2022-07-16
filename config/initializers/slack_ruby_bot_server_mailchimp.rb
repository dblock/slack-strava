SlackRubyBotServer::Mailchimp.configure do |config|
  config.mailchimp_api_key = ENV.fetch('MAILCHIMP_API_KEY', nil)
  config.mailchimp_list_id = ENV.fetch('MAILCHIMP_LIST_ID', nil)
  config.additional_member_tags = ['slava']
  config.additional_merge_fields = { 'BOT' => 'Slava' }
end
