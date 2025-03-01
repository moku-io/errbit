# config valid only for Capistrano 3.1
lock '3.4.0'
set :rvm_ruby_version, '2.7.3'

# TODO: Remember to change to project
set :application, "errbit_#{fetch(:stage)}"
set :repo_url, 'git@github.com:moku-io/errbit.git'

# Default branch is 'master'
set :branch, ENV['REVISION'] || ENV['BRANCH_NAME'] || 'master'

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Don't change these unless you know what you're doing
set :user, 'deploy'
set :pty, true
set :use_sudo,        false
set :deploy_via,      :remote_cache
set :deploy_to,       "/home/#{fetch(:user)}/apps/#{fetch(:application)}"
set :ssh_options,     forward_agent: true, auth_methods: ['publickey']
set :puma_bind,       "unix://#{shared_path}/tmp/sockets/puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.error.log"
set :puma_error_log,  "#{release_path}/log/puma.access.log"
set :puma_worker_timeout, nil
set :puma_init_active_record, true # Change to true if using ActiveRecord
set :puma_restart_command, 'bundle exec --keep-file-descriptors puma'
set :nginx_root_path, '/etc/nginx'
set :nginx_sites_available, 'sites-available'
set :nginx_sites_enabled, 'sites-enabled'
set :nginx_template, "#{stage_config_path}/nginx.conf.erb"
set :app_server, true
set :app_server_socket, "#{shared_path}/tmp/sockets/puma.sock"

## Defaults:
# set :scm,           :git
# set :branch,        :master
# set :format,        :pretty
# set :log_level,     :debug
# set :keep_releases, 5

## Linked Files & Directories (Default None):
set :linked_files, %w[.env]
set :linked_dirs,  %w[log tmp/pids tmp/sockets tmp/cache public/assets public/.well-known]

namespace :deploy do
  desc 'Create required directories'
  task :make_dirs do
    on roles(:app) do
      execute :mkdir, "#{shared_path}/tmp/sockets -p"
      execute :mkdir, "#{shared_path}/tmp/pids -p"
      execute :mkdir, "#{shared_path}/tmp/log -p"
      execute :mkdir, "#{shared_path}/public/system -p"
      execute :mkdir, "#{shared_path}/public/.well-known -p"
      execute :mkdir, "#{shared_path}/db_backups -p"
      execute :mkdir, "#{shared_path}/ssl -p"
      execute :mkdir, "#{shared_path}/nginx_cache -p"
    end
  end

  desc 'Initial Deploy'
  task :initial do
    before 'deploy:starting', 'deploy:make_dirs'
    before 'deploy:updated', 'db_create'
    # before 'deploy:restart', 'puma:start'

    on roles(:app) do
      set(:nginx_use_ssl, false)
      invoke 'deploy'
      invoke 'deploy:lets_encrypt' if fetch(:nginx_use_ssl)
      invoke 'nginx:site:add'
      invoke 'nginx:site:enable'
      invoke 'puma:monit:config'
    end
  end

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke 'puma:restart'
    end
  end

  desc 'Clear cache'
  task :clear_cache do
    on roles(:app), in: :sequence, wait: 5 do
      execute "rm -R #{shared_path}/nginx_cache/*"
    rescue StandardError
      nil
      # TODO: execute :rm, '-R' funziona?
    end
  end

  # Automatically create the DB https://github.com/capistrano/rails/pull/36
  desc 'Create Database'
  task :db_create do
    on roles(:app), in: :sequence, wait: 5 do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'db:create'
        rescue StandardError
          nil
        end
      end
    end
  end

  desc 'Init let\'s encrypt'
  task :lets_encrypt do
    on roles(:app) do
      # Run letsencrypt to generate the certs
      # Prerequisites:
      #    sudo apt-get install letsencrypt
      domains_list = fetch(:lets_encrypt_domains).split(' ').collect { |d| "-d #{d}" }.join(' ')
      execute "sudo letsencrypt certonly --webroot -w #{current_path}/public/ #{domains_list} --email #{fetch(:lets_encrypt_email)} --agree-tos -n"

      # Generate DH parameters for EDH ciphers
      execute :mkdir, "#{shared_path}/ssl -p"
      execute "openssl dhparam -out #{shared_path}/ssl/dhparams.pem 4096 2> /dev/null"
    end
  end

  desc 'Enable HTTPS'
  task :enable_https do
    on roles(:app) do
      set(:nginx_use_ssl, true)
      invoke 'deploy:lets_encrypt'
      invoke 'nginx:site:add'
      invoke 'nginx:site:enable'
      invoke 'nginx:reload'
    end
  end

  # before :starting,     :check_revision
  after  :finishing,    :compile_assets
  after  :finishing,    :cleanup
  after  :finishing,    :restart
  after  :finished,     :clear_cache
end

# TODO: https://github.com/capistrano/rails#uploading-your-masterkey
