# config valid only for current version of Capistrano
lock '3.5.0'
# Change these
server '192.241.179.145', port: 22, roles: [:app, :db], primary: true

set :repo_url,        'git@github.com:dreyxvx/recommender_system_api.git'
set :application,     'recommender_system_api'
set :user,            'deploy'
set :puma_threads,    [4, 16]
set :puma_workers,    0

# Don't change these unless you know what you're doing
set :pty,             false
set :use_sudo,        false
set :stage,           :production
set :deploy_via,      :remote_cache
set :deploy_to,       "/home/#{fetch(:user)}/apps/#{fetch(:application)}"
set :puma_bind,       "unix://#{shared_path}/tmp/sockets/#{fetch(:application)}-puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.error.log"
set :puma_error_log,  "#{release_path}/log/puma.access.log"
set :ssh_options,     forward_agent: true, user: fetch(:user), keys: %w(~/.ssh/id_rsa.pub)
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_init_active_record, true # Change to false when not using ActiveRecord
set :sidekiq_role, :app
set :sidekiq_pid, File.join(shared_path, 'tmp', 'pids', 'sidekiq.pid')
set :sidekiq_config, "#{release_path}/config/sidekiq.yml"
set :sidekiq_env, 'production'
set :sidekiq_default_hooks, false
set :sidekiq_log, File.join(shared_path, 'log', 'sidekiq.log')
## Defaults:
# set :scm,           :git
# set :branch,        :master
# set :format,        :pretty
# set :log_level,     :debug
# set :keep_releases, 5

## Linked Files & Directories (Default None):
set :linked_files, %w(config/database.yml config/secrets.yml)
set :linked_dirs,  fetch(:linked_dirs, []).push('tmp/pids', 'tmp/cache', 'tmp/sockets', 'log')

namespace :puma do
  desc 'Create Directories for Puma Pids and Socket'
  task :make_dirs do
    on roles(:app) do
      execute "mkdir #{shared_path}/tmp/sockets -p"
      execute "chmod g+rx,u+rwx #{shared_path}/tmp/sockets"

      execute "mkdir #{shared_path}/tmp/pids -p"
      execute "chmod g+rx,u+rwx #{shared_path}/tmp/pids"

      execute "mkdir #{shared_path}/log -p"
      execute "chmod g+rx,u+rwx #{shared_path}/log"

      execute "mkdir #{shared_path}/config -p"
      execute "chmod g+rx,u+rwx #{shared_path}/config"
    end
  end
  before :start, :make_dirs
end

namespace :deploy do
  desc 'Make sure local git is in sync with remote.'
  task :check_revision do
    on roles(:app) do
      invoke 'sidekiq:quiet'
      unless `git rev-parse HEAD` == `git rev-parse origin/master`
        logger.info  'WARNING: HEAD is not the same as origin/master'
        logger.info  'Run `git push` to sync changes.'
        exit
      end
    end
  end

  desc 'Initial Deploy'
  task :initial do
    on roles(:app) do
      before 'deploy:restart', 'puma:start'
      invoke 'deploy'
    end
  end

  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke 'sidekiq:stop'
      invoke 'sidekiq:start'
      invoke 'puma:restart'
    end
  end

  task :add_default_hooks do
    after 'deploy:starting', 'sidekiq:quiet'
    after 'deploy:updated', 'sidekiq:stop'
    after 'deploy:reverted', 'sidekiq:stop'
    after 'deploy:published', 'sidekiq:start'
  end

  before :starting,     :check_revision
  # after  :finishing,    :compile_assets
  after  :finishing,    :cleanup
  after  :finishing,    :restart
end

# ps aux | grep puma    # Get puma pid
# kill -s SIGUSR2 pid   # Restart puma
# kill -s SIGTERM pid   # Stop puma
