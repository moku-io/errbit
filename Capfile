# https://coderwall.com/p/ttrhow

# Load DSL and Setup Up Stages
require 'capistrano/setup'

# Includes default deployment tasks
require 'capistrano/deploy'

# Includes tasks from other gems included in your Gemfile
#
# For documentation on these, see for example:
#
#   https://github.com/capistrano/rvm
#   https://github.com/capistrano/rbenv
#   https://github.com/capistrano/chruby
#   https://github.com/capistrano/bundler
#   https://github.com/capistrano/rails

require 'capistrano/rvm'
require 'capistrano/rbenv' if ENV['rbenv']
require 'capistrano/rails/assets'
require 'capistrano/puma'
require 'capistrano/rails'
require 'capistrano/nginx'
require 'capistrano/puma/monit'

Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }
