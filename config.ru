$LOAD_PATH.unshift(File.dirname(__FILE__))

ENV['RACK_ENV'] ||= 'development'

require 'bundler/setup'
Bundler.require :default, ENV.fetch('RACK_ENV', nil)

require 'slack-ruby-bot-server'
require 'slack-strava'

SlackRubyBotServer::RealTime.configure do |config|
  config.server_class = SlackStrava::Server
end

NewRelic::Agent.manual_start

SlackStrava::App.instance.prepare!

Thread.abort_on_exception = true

Thread.new do
  SlackRubyBotServer::Service.instance.start_from_database!
  SlackStrava::App.instance.after_start!
end

run Api::Middleware.instance
