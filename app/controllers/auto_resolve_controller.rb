class AutoResolveController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_honeybadger_secret

  def honeybadger
    Rails.logger.info("\nPARAMS: #{params}\n")
    Rails.logger.info("\mBODY: #{request.body}\n")

    head 200
  end

  def verify_honeybadger_secret
  end
end