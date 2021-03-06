require 'mina/bundler'
require 'mina/rails'
require 'mina/git'
# require 'mina/rbenv'
require 'mina_sidekiq/tasks'
require 'mina/puma'
require 'mina/rvm'

set :domain, '162.243.223.220'
set :deploy_to, '/home/deploy/apps/recommender_system_api/'
set :repository, 'git@github.com:dreyxvx/recommender_system_api.git'
set :branch, 'master'
set :user, 'deploy'
set :forward_agent, true
set :port, '22'
# set_default :rvm_path, '$HOME/.rvm/scripts/rvm'
# set :unicorn_pid, "#{deploy_to}/shared/pids/unicorn.pid"

# Manually create these paths in shared/ (eg: shared/config/database.yml) in your server.
# They will be linked in the 'deploy:link_shared_paths' step.
set :shared_paths, ['config/database.yml', 'log', 'tmp/pids', 'config/secrets.yml']

# This task is the environment that is loaded for most commands, such as
# `mina deploy` or `mina rake`.
task :environment do
  queue %(echo "-----> Loading environment"#{echo_cmd %(source ~/.bashrc)})
  # invoke :'rbenv:load'
  invoke :'rvm:use[ruby-2.2.2]'
  # If you're using rbenv, use this to load the rbenv environment.
  # Be sure to commit your .rbenv-version to your repository.
end

# Put any custom mkdir's in here for when `mina setup` is ran.
# For Rails apps, we'll make some of the shared paths that are shared between
# all releases.
task setup: :environment do
  queue! %(mkdir -p "#{deploy_to}/shared/log")
  queue! %(chmod g+rx,u+rwx "#{deploy_to}/shared/log")

  queue! %(mkdir -p "#{deploy_to}/shared/config")
  queue! %(chmod g+rx,u+rwx "#{deploy_to}/shared/config")

  queue! %(touch "#{deploy_to}/shared/config/database.yml")
  # queue  %(echo "-----> Be sure to edit 'shared/config/database.yml'.")

  queue! %(touch "#{deploy_to}/shared/config/secrets.yml")
  # queue %(echo "-----> Be sure to edit 'shared/config/secrets.yml'.")

  # sidekiq needs a place to store its pid file and log file

  queue! %(mkdir -p "#{deploy_to}/shared/tmp/sockets")
  queue! %(chmod g+rx,u+rwx "#{deploy_to}/shared/tmp/sockets")

  queue! %(mkdir -p "#{deploy_to}/shared/pids/")
  queue! %(chmod g+rx,u+rwx "#{deploy_to}/shared/pids")
end

desc 'Deploys the current version to the server.'
task deploy: :environment do
  deploy do
    # stop accepting new workers
    invoke :'sidekiq:quiet'

    invoke :'git:clone'
    invoke :'deploy:link_shared_paths'
    invoke :'bundle:install'
    invoke :'rails:db_migrate'
    invoke :'rails:assets_precompile'

    to :launch do
      invoke :'sidekiq:restart'
      invoke :'puma:stop'
      invoke :'puma:start'
    end
  end
end
