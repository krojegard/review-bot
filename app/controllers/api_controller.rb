class ApiController < ApplicationController
  skip_before_action :verify_authenticity_token

  def pull_request
    pr = params['api']['pull_request'].to_unsafe_h
    pr_url = pr['url']

    # Put more advanced logic here
    approve_request(pr_url) if files_match?(pr)

    head 200
  end

  def files_match?(pull_request)
    auto_approve = ignored_files(pull_request)

    changed_files(pull_request['url']).each do |changed_file|
      match = false
      auto_approve.each do |pattern|
        next if match || match?(pattern, changed_file)
      end
      return false unless match
    end

    true
  end

  def match?(pattern, file)
    return false if pattern.blank?

    pattern.gsub!('/', '\/').gsub!('*', '[^\/]*')
    regex_pattern = if pattern.start_with?('\/')
      /^#{pattern}$/ # Match the pattern exactly
    else
      /#{pattern}$/ # Only match the end of the file name
    end

    file =~ regex_pattern
  end

  def approve_request(pr_url)
    uri = URI(pr_url + '/reviews')
    request = ::Net::HTTP::Post.new(
      uri,
      {
        'Content-Type' => 'application/json',
        'Authorization' => "token #{ENV['GITHUB_API_KEY']}"
      }
    )

    request.body = {
      commit_id:  get_last_commit_sha(pr_url),
      event: 'APPROVE'
    }.to_json

    ::Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
  end

  def changed_files(pr_url)
    uri = URI.parse(pr_url + '/files')
    request = ::Net::HTTP::Get.new(
      uri,
      {
        'Authorization' => "token #{ENV['GITHUB_API_KEY']}"
      }
    )

    response = ::Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

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

    uri = URI.parse("#{base_url}/.auto-approve?ref=#{sha}")
    request = ::Net::HTTP::Get.new(
      uri,
      {
        'Authorization' => "token #{ENV['GITHUB_API_KEY']}"
      }
    )

    response = ::Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    return [] unless response.code == 200

    content = JSON.parse(response.body)['content']
    Base64.decode64(content).split("\n")
  end

  def get_last_commit_sha(pr_url)
    uri = URI.parse(pr_url + '/commits')
    request = ::Net::HTTP::Get.new(
      uri,
      {
        'Authorization' => "token #{ENV['GITHUB_API_KEY']}"
      }
    )

    response = ::Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    commits = JSON.parse(response.body)
    commits.last['sha']
  end
end