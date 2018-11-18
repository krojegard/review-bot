class ApiController < ApplicationController
  skip_before_action :verify_authenticity_token

  def pull_request
    file = File.new(Rails.root + 'results/' + DateTime.now.to_s, 'w')
    pretty_json = JSON.pretty_generate(params['api'].to_unsafe_h)
    file.write(pretty_json)
    file.close
    head 200
  end
end