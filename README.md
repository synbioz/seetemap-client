# How to use

- Add gem 'seetemap-client' to Gemfile
- bundle install
- Create config/seetemap.yml

## Sinatra

- In application file add require 'seetemap\_client'
- For sinatra, use middleware in rackup file (config.ru), like this: use SeetemapClient::Application

## Rails

- In application.rb add config.middleware.use "SeetemapClient::Application"

## Seetemap.yml

  seetemap:
    auth_token: "account token"
    site_token: "api_key"
    keep_delay: 3600
