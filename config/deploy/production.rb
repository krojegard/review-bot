# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

# server "example.com", user: "deploy", roles: %w{app db web}, my_property: :my_value
# server "example.com", user: "deploy", roles: %w{app web}, other_property: :other_value
# server "db.example.com", user: "deploy", roles: %w{db}

server  'charon-reach.reachnetwork.com',
        user: 'capuser',
        roles: %w[web app],
        ssh_options: {
          forward_agent: true
        }

set :branch, 'master'

# role-based syntax
# ==================

# Defines a role with one or multiple servers. The primary server in each
# group is considered to be the first unless any hosts have the primary
# property set. Specify the username and a domain or IP for the server.
# Don't use `:all`, it's a meta role.

# role :app, %w{deploy@example.com}, my_property: :my_value
# role :web, %w{user1@primary.com user2@additional.com}, other_property: :other_value
# role :db,  %w{deploy@example.com}
role :app, "charon-reach.reachnetwork.com"
role :web, "charon-reach.reachnetwork.com"

set :rbenv_type, :user # Defaults to: :auto
set :rbenv_ruby, File.read('.ruby-version').strip # Defaults to: 'default'
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_roles, :all

# NOTE : You cannot have this uncommented. We've had it in previous deploy files, but with Puma it causes an issue. The default value coming from Capistrano is correct, and it should just be allowed to use that.
# set :rbenv_map_bins, %w{rake gem bundle ruby rails puma pumactl}# honeybadger sidekiq sidekiqctl

set :puma_threads, [4, 16]
set :puma_workers, 2