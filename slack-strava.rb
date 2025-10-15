ENV['RACK_ENV'] ||= 'development'

require 'bundler/setup'
Bundler.require :default, ENV.fetch('RACK_ENV', nil)

Dir["#{File.expand_path('config/initializers', __dir__)}/**/*.rb"].sort.each do |file|
  require file
end

Mongoid.load! File.expand_path('config/mongoid.yml', __dir__), ENV.fetch('RACK_ENV', nil)

require 'slack-ruby-bot'
require 'slack-strava/version'
require 'slack-strava/service'
require 'slack-strava/info'
require 'slack-strava/models'
require 'slack-strava/api'
require 'slack-strava/app'
require 'slack-strava/server'
require 'slack-strava/commands'
