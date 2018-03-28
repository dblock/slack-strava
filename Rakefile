require 'rubygems'
require 'bundler'

Bundler.setup :default, :development

unless ENV['RACK_ENV'] == 'production'
  require 'rspec/core'
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec) do |spec|
    spec.pattern = 'spec/**/*_spec.rb'
  end

  require 'rubocop/rake_task'
  RuboCop::RakeTask.new

  task default: %i[rubocop spec]

  import 'tasks/db.rake'
end
