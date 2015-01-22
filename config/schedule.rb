# Manually load Figaro to get ENVs even if Rails is not initialized
require 'figaro'
Figaro.application = Figaro::Application.new(environment: ENV['RAILS_ENV'], path: "config/application.yml")
Figaro.load

# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

