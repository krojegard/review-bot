class AutoResolveController < ApplicationController
  skip_before_action :verify_authenticity_token

  HONEYBADGER_TOKEN = "At5xREmWEhkuJp2XdMyv"
  BRENNEN_USER_ID = 60991

  def honeybadger
    Rails.logger.info("\nPARAMS: #{params}\n")
    Rails.logger.info("\mBODY: #{request.body}\n")

    render plain: 'success', status: 200
  end

  def pagerduty
    Rails.logger.info("\nPARAMS: #{params}\n")
    Rails.logger.info("\mBODY: #{request.body}\n")

    render plain: 'success', status: 200
  end

  # def pagerduty
  #   messages = params[:messages]
  #   unless messages && messages.is_a?(Array) && messages.count > 0
  #     render plain: 'bad request', status: 400
  #     return
  #   end

  #   messages.each do |message|
  #     case message['type']
  #     when 'incident.resolve'
  #       update_honeybadger_issue(project_id, fault_id, {resolved: true})
  #     when 'incident.assign'
  #       update_honeybadger_issue(project_id, fault_id, {assignee_id: assignee})
  #     end
  #   end

  #   render plain: 'success', status: 200
  # end

  # def update_honeybadger_issue(project_id, fault_id, data)
  #   uri = URI("https://app.honeybadger.io/v2/projects/#{project_id}/faults/#{fault_id}")
  #   request = Net::HTTP::Put.new(uri)
  #   request.basic_auth(HONEYBADGER_TOKEN)
  #   request.body = {fault: data}.to_json

  #   Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
  #     result = http.request(request)

  #     unless result.code.match?(/2??/)
  #       raise "Honeybadger request failed"
  #     end
  #   end
  # end
# 
  # def verify_honeybadger_secret
  # end
end