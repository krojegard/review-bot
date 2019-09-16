Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  get '/', to: 'home#index'
  post '/api/v1/pull-request', to: 'api#pull_request'
  post '/api/v1/honeybadger', to: 'auto_resolve#honeybadger'
end
