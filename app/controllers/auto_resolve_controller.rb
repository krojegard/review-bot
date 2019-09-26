class AutoResolveController < ApplicationController
  skip_before_action :verify_authenticity_token

  HONEYBADGER_TOKEN = "At5xREmWEhkuJp2XdMyv".freeze
  BRENNEN_USER_ID = 60991

  # Keys are PagerDuty ids, keys are HoneyBadger ids
  PROJECT_IDS = {
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

  def honeybadger
    Rails.logger.info("\n\nHONEYBADGER")

    case params[:event]
    when 'assigned'
    when 'resolved'
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
      project_id = PROJECT_IDS[project]
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
    request.basic_auth(HONEYBADGER_TOKEN)
    request.body = {fault: data}.to_json

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      result = http.request(request)

      unless result.code.match?(/2??/)
        raise "Honeybadger request failed"
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
    request = Net::HTTP::GET.new(uri)
    request.basic_auth(HONEYBADGER_TOKEN)

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      result = http.request(request)
      raise "Honeybadger request failed" unless result.code.match?(/2??/)

      Rails.logger.info("BODY: #{result.body}")

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
end