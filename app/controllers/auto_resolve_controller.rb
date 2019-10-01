class AutoResolveController < ApplicationController
  skip_before_action :verify_authenticity_token

  HONEYBADGER_TOKEN = "At5xREmWEhkuJp2XdMyv".freeze
  PAGERDUTY_TOKEN = "MuwLJo-CrKbPiW39vtx7".freeze
  BRENNEN_USER_ID = 60991

  # Keys are PagerDuty ids, keys are HoneyBadger ids
  HB_PROJECT_IDS = {
    'CND' => 35165,
    'EC2 Worker' => 35297,
    'EDU Admin' => 2053,
    'Feed Processor' => 55447,
    'GP-Beta' => 59555,
    'GradReports' => 35485,
    'GraduatePrograms' => 47932,
    'GTOS' => 35164,
    'H2B' => 42944,
    'Hermes (formerly Postly)' => 2055,
    'Log Parser' => 52741,
    'MBACompass' => 64664,
    'NursingCareer' => 59664,
    'OnlineU' => 2681,
    'Optimal Docs' => 58163,
    'Optimal' => 61612,
    'Outreach' => 53618,
    'Reach Admin' => 57030,
    'Reach Network' => 57104,
    'Redirections' => 42198,
    'Review Bot' => 58360,
    'SocialWorkDegree' => 59665,
    'SR Investment Group' => 57105,
    'SRCorp' => 39889,
    'Switchup' => 56512,
    'Talentdesk' => 54667,
    'TD Admin' => 49828
  }.freeze

  PD_PROJECT_IDS = {
    "Honeybadger EDU-Specialty" => "PTRSJ4B",
    "Honeybadger Outreach-Publishing" => "PW5NKM5",
    "Honeybadger Reporting-Vendors" => "POJBJXS",
    "Honeybadger TD" => "PQ32C29"
  }.freeze

  def honeybadger(params)
    Rails.logger.info("\n\nHONEYBADGER")

    return unless params['fault']&.is_a?(Hash) && params['fault']['environment'] == 'production'

    fault_id = params['fault']['id']
    assignee_email = params['actor']['email']

    pd_incident = @pd_incidents&.select{ |incident| incident[:fault_id] == fault_id }&.first
    if pd_incident.nil? # The incidents we have may be out of date, so refresh them
      self.fetch_all_pd_incidents
      pd_incident = @pd_incidents&.select{ |incident| incident[:fault_id] == fault_id }&.first
    end

    return if pd_incident.nil? # Incident has already been resolved or doesn't exist

    case params['event']
    when 'assigned'
      nil
      # user_first_name = params['assignee']['name'].split(' ').first
      # data = {
      #   incident: {
      #     type: 'incident_reference',
      #     status: 'resolved'
      #   }
      # }
      # update_pagerduty_issue(pd_incident[:id], assignee_email, data)
    when 'resolved'
      data = {
        incident: {
          type: 'incident_reference',
          status: 'resolved'
        }
      }
      update_pagerduty_issue(pd_incident[:id], assignee_email, data)
    end

    render plain: 'success', status: 200
  end

  def pagerduty
    Rails.logger.info("\n\nPAGERDUTY")
    messages = params[:messages]
    unless messages&.is_a?(Array) && messages.count.positive?
      render plain: 'bad request', status: 400
      return
    end

    messages.each do |message|
      title = message['incident']['title'] # i.e "[Outreach/Production] Error Message"
      project = title.match(/\[(.*?)\/.*?\]/)[1] # Outreach
      project_id = HB_PROJECT_IDS[project]
      fault_id = message['incident']['alerts'].first['alert_key'].split('-')[1]
      Rails.logger.info("\n\nTITLE: #{title}")
      Rails.logger.info("\n\nproject: #{project}")
      Rails.logger.info("\n\nproject_id: #{project_id}")
      Rails.logger.info("\n\nfault_id: #{fault_id}")

      case message['event']
      when 'incident.resolve'
        update_honeybadger_issue(project_id, fault_id, {resolved: true})
      when 'incident.assign'
        user_first_name = message['log_entries'].first['assignees'].first['summary'].split(' ').first
        user_id = self.users[user_first_name]
        Rails.logger.info("\n\nUSER FIRST NAME: #{user_first_name}")
        Rails.logger.info("\n\nUSERS: #{self.users}")
        Rails.logger.info("\n\nUSER ID: #{user_id}")
        update_honeybadger_issue(project_id, fault_id, {assignee_id: user_id})
      end
    end

    render plain: 'success', status: 200
  end

  def update_honeybadger_issue(project_id, fault_id, data)
    uri = URI("https://app.honeybadger.io/v2/projects/#{project_id}/faults/#{fault_id}")
    request = Net::HTTP::Put.new(uri)
    request.basic_auth(HONEYBADGER_TOKEN, nil)
    request.body = {fault: data}.to_json

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      result = http.request(request)

      unless result.code.match?(/2??/)
        raise "Honeybadger request failed"
      end
    end
  end

  def update_pagerduty_issue(incident_id, email, data)
    uri = URI("https://api.pagerduty.com/incidents/#{incident_id}")
    request = Net::HTTP::Put.new(uri)
    request['Authorization'] = "Token token=#{PAGERDUTY_TOKEN}"
    request['Content-Type'] = "application/json"
    request['From'] = email
    request.body = data.to_json

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      result = http.request(request)

      unless result.code.match?(/2??/)
        raise "Pagerduty request failed"
      end
    end
  end

  def users
    @users_last_updated ||= Time.current - 2.days
    # Fetch users from honeybadger every 24 hours
    fetch_users if Time.current - @users_last_updated > 86400
    @users
  end

  def fetch_users
    uri = URI("https://app.honeybadger.io/v2/teams/32224")
    request = Net::HTTP::Get.new(uri)
    request.basic_auth(HONEYBADGER_TOKEN, nil)

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      result = http.request(request)
      raise "Honeybadger request failed" unless result.code.match?(/2??/)

      @users = JSON.parse(result.body)['members'].map do |user|
        [
          user['name'].split(' ').first,
          user['id']
        ]
      end
      @users = @users.to_h
    end

    @users_last_updated = Time.current
  end

  def fetch_all_pd_incidents
    @pd_incidents = []
    more_records = true
    offset = 0

    while more_records
      incidents, more_records = fetch_pd_incidents(100, 0, PD_PROJECT_IDS.values)
      @pd_incidents += incidents
      offset += 100
    end
  end

  def fetch_pd_incidents(limit, offset, project_ids)
    service_ids = project_ids.map{ |pid| "service_ids[]=#{pid}" }.join('&')
    uri = URI("https://api.pagerduty.com/incidents?limit=#{limit}&offset=#{offset}&include[]=first_trigger_log_entries&#{service_ids}&statuses[]=acknowledged&statuses[]=triggered")
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Token token=#{PAGERDUTY_TOKEN}"
    body = nil
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      result = http.request(request)
      body = JSON.parse(result.body)
    end
    incidents = []
    body['incidents'].each do |incident|
      event_type = incident['first_trigger_log_entry']['channel']['details']['event']
      next unless event_type == 'occurred'

      incidents << {
        id: incident['id'],
        incident_number: incident['incident_number'],
        title: incident['title'],
        fault_id: incident['first_trigger_log_entry']['channel']['details']['notice']['fault_id']
      }
    end
    [incidents, body['more']]
  end
end