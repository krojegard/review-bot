class ApiController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_github_secret

  def pull_request
    head 400 unless request.env['HTTP_X_HUB_SIGNATURE'] == 'pull_request'

    logger.info "FULL REQUEST: "
    pr = params['api']['pull_request'].to_unsafe_h

    approve_request(pr) if files_match?(pr) && needs_review?(pr)

    head 200
  end

  def files_match?(pull_request)
    auto_approve = ignored_files(pull_request)

    changed = changed_files(pull_request)

    return false if changed.nil?

    changed.each do |changed_file|
      match = false
      auto_approve.each do |pattern|
        next if match

        match = true if match?(pattern, changed_file)
      end
      return false unless match
    end

    true
  end

  def needs_review?(pull_request)
    uri = URI.parse(pull_request['url'] + '/reviews')
    request = ::Net::HTTP::Get.new(
      uri,
      {
        'Authorization' => "token #{ENV['GITHUB_API_KEY']}"
      }
    )

    response = ::Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    return true unless response.code == '200'

    last_review = JSON.parse(response.body).last
    return true if last_review.nil?

    review_is_current = last_review['commit_id'] == pull_request['head']['sha']
    review_is_approved = last_review['state'] == 'APPROVED'

    return true unless review_is_current && review_is_approved

    false
  end

  def match?(pattern, file)
    return false if pattern.blank?

    pattern.gsub!('/', '\/')
    pattern.gsub!('*', '[^\/]*')
    regex_pattern = if pattern.start_with?('\/')
      pattern.gsub!(/^\\\//, '')
      /^#{pattern}$/ # Match the pattern exactly
    else
      /#{pattern}$/ # Only match the end of the file name
    end

    file =~ regex_pattern
  end

  def approve_request(pull_request)
    uri = URI(pull_request['uri'] + '/reviews')
    request = ::Net::HTTP::Post.new(
      uri,
      {
        'Content-Type' => 'application/json',
        'Authorization' => "token #{ENV['GITHUB_API_KEY']}"
      }
    )

    sha = pull_request['head']['sha']

    request.body = {
      commit_id: sha,
      event: 'APPROVE',
      body: "This PR has been auto-approved since it contains changes that don't require a human review."
    }.to_json

    ::Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
  end

  def changed_files(pull_request)
    uri = URI.parse(pull_request['url'] + '/files')
    request = ::Net::HTTP::Get.new(
      uri,
      {
        'Authorization' => "token #{ENV['GITHUB_API_KEY']}"
      }
    )

    response = ::Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    return unless response.code == '200'

    files = JSON.parse(response.body)

    file_names = []
    files.each do |file|
      file_names << file['filename']
    end

    file_names
  end

  def ignored_files(pull_request)
    base_url = pull_request['base']['repo']['url']
    sha = pull_request['base']['sha']

    uri = URI.parse("#{base_url}/contents/.auto-approve?ref=#{sha}")
    request = ::Net::HTTP::Get.new(
      uri,
      {
        'Authorization' => "token #{ENV['GITHUB_API_KEY']}"
      }
    )

    response = ::Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    return [] unless response.code == '200'

    content = JSON.parse(response.body)['content']
    Base64.decode64(content).split("\n")
  end

  def verify_github_secret
    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['GITHUB_SECRET_TOKEN'], request.raw_post)
    logger.info "HASH SIGNATURE FROM YAML: #{signature}"
    logger.info "SECRET FROM YAML: #{ENV['GITHUB_SECRET_TOKEN']}"
    logger.info "HEADERS: #{request.headers.inspect}"

    head 401 unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
  end
end