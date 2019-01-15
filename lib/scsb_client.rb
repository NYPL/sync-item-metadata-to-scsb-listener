require 'rubygems'
require 'net/http'
require 'uri'

require_relative 'errors'
require_relative 'kms_client'

class ScsbClient

  def initialize
    kms_client = KmsClient.new
    raise "Missing required ENV config: SCSB_API_KEY" if ENV['SCSB_API_KEY'].nil? || ENV['SCSB_API_KEY'].empty?
    raise "Missing required ENV config: SCSB_API_BASE_URL" if ENV['SCSB_API_BASE_URL'].nil? || ENV['SCSB_API_BASE_URL'].empty?

    @api_key = kms_client.decrypt(ENV['SCSB_API_KEY']).strip
    @api_base_url = kms_client.decrypt(ENV['SCSB_API_BASE_URL']).strip
  end

  def items_by_bib_id (id)
    result = self.search fieldName: 'OwningInstitutionBibId', fieldValue: id

    raise ScsbError.new(e), "SCSB returned no match for id #{id}" if result['searchResultRows'].empty?
    CustomLogger.debug "Retrieved bib by id #{id} from scsb", result

    result['searchResultRows']
  end

  def item_by_barcode (barcode)
    result = self.search fieldName: 'Barcode', fieldValue: barcode

    raise ScsbError.new(e), "SCSB returned no match for barcode #{barcode}" if result['searchResultRows'].empty?

    result['searchResultRows'].first
  end

  def search (params)
    _post 'searchService/search', params
  end

  private

  def _post (path, body)
    uri = URI.parse("#{@api_base_url}/#{path}")

    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.path, initheader = _headers)
    req.body = body.to_json
    res = https.request(req)

    raise ScsbError.new(e), "Error response from SCSB API: statusCode=#{res.code}" if res.code.to_i >= 400

    JSON.parse(res.body)
  end

  def _headers
    return {
      'Accept': 'application/json',
      'api_key': @api_key,
      'Content-Type': 'application/json'
    }
  end
end
