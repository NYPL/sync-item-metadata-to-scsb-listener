require 'oauth2'
require 'net/http'
require 'net/https'
require 'uri'

require_relative 'kms_client'
require_relative 'custom_logger'

class PlatformApiClient
  def initialize
    raise 'Missing config: NYPL_OAUTH_ID is unset' if ENV['NYPL_OAUTH_ID'].nil? || ENV['NYPL_OAUTH_ID'].empty?
    raise 'Missing config: NYPL_OAUTH_SECRET is unset' if ENV['NYPL_OAUTH_SECRET'].nil? || ENV['NYPL_OAUTH_SECRET'].empty?

    kms_client = KmsClient.new
    @client_id = kms_client.decrypt(ENV['NYPL_OAUTH_ID'])
    @client_secret = kms_client.decrypt(ENV['NYPL_OAUTH_SECRET'])

    @oauth_site = ENV['NYPL_OAUTH_URL']
  end

  def get (path, options = {})
    options = {
      authenticated: true
    }.merge options

    authenticate! if options[:authenticated]

    uri = URI.parse("#{ENV['PLATFORM_API_BASE_URL']}#{path}")

    CustomLogger.debug "Getting from platform api", { uri: uri }

    begin
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@access_token}" if options[:authenticated]
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme === 'https') do |http|
        http.request(request)
      end

      CustomLogger.debug "Got platform api response", { code: response.code, body: response.body }

      parse_json_response response

    rescue Exception => e
      raise AvroError.new(e), "Failed to retrieve #{path} schema: #{e.message}"
    end
  end 

  def post (path, body, options = {})
    options = {
      authenticated: true
    }.merge options

    authenticate! if options[:authenticated]

    uri = URI.parse("#{ENV['PLATFORM_API_BASE_URL']}#{path}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme === 'https'

    request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    request.body = body.to_json

    CustomLogger.debug "Posting to platform api", { uri: uri, body: body }

    # Add bearer token header
    request['Authorization'] = "Bearer #{@access_token}" if options[:authenticated]

    # Execute request:
    response = http.request(request)

    CustomLogger.debug "Got platform api response", { code: response.code, body: response.body }
  
    parse_json_response response
  end

  private

  def parse_json_response (response)
    if response.code == "200"
      JSON.parse(response.body)
    elsif response.code == "401"
      # Likely an expired access-token; Wipe it for next run
      @access_token = nil
    else
      raise "Error posting to #{path} #{response.code}: #{response.body}"
      {}
    end
  end

  # Authorizes the request.
  def authenticate!
    # NOOP if we've already authenticated
    return nil if ! @access_token.nil?

    uri = URI.parse("#{@oauth_site}oauth/token")
    request = Net::HTTP::Post.new(uri)
    request.basic_auth(@client_id, @client_secret)
    request.set_form_data(
      "grant_type" => "client_credentials"
    )

    req_options = {
      use_ssl: uri.scheme == "https",
      request_timeout: 500
    }

    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end

    if response.code == '200'
      @access_token = JSON.parse(response.body)["access_token"]
    else
      nil
    end
  end

end
