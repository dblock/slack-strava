SlackRubyBotServer::Mailchimp.configure do |config|
  config.mailchimp_api_key = ENV['MAILCHIMP_API_KEY']
  config.mailchimp_list_id = ENV['MAILCHIMP_LIST_ID']
  config.additional_member_tags = ['slava']
  config.additional_merge_fields = { 'BOT' => 'Slava' }
end
