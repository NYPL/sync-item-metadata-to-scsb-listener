require 'rubygems'
require 'net/http'
require 'uri'

require_relative 'errors'
require_relative 'kms_client'
require_relative 'sierra_mod_11'

class ScsbClient

  def initialize
    kms_client = KmsClient.new
    raise "Missing required ENV config: SCSB_API_KEY" if ENV['SCSB_API_KEY'].nil? || ENV['SCSB_API_KEY'].empty?
    raise "Missing required ENV config: SCSB_API_BASE_URL" if ENV['SCSB_API_BASE_URL'].nil? || ENV['SCSB_API_BASE_URL'].empty?

    @api_key = kms_client.decrypt(ENV['SCSB_API_KEY']).strip
    @api_base_url = kms_client.decrypt(ENV['SCSB_API_BASE_URL']).strip
  end

  # Get barcodes by bibid
  # Returns [] if no barcodes identified
  def barcodes_by_bib_id (id)
    items_by_bib_id(id).inject([]) do |barcodes, item|
      barcodes << item['barcode'] if item['barcode']
      # Add nested records (typical for serials):
      serial_barcodes = item['searchItemResultRows']
        .map { |serial_row| serial_row['barcode'] }
        .compact
      barcodes + serial_barcodes
    end
  end

  # Get items by bibid
  # Returns [] if no items found
  def items_by_bib_id (id)
    # Add prefix and suffix to id to match id in scsb:
    bookended_id = ".b#{SierraMod11.mod11(id)}"
    result = self.search fieldName: 'OwningInstitutionBibId', fieldValue: bookended_id, "owningInstitutions": [ "NYPL" ]

    $logger.debug "Retrieved items by bib id #{id} from scsb", result

    result['searchResultRows']
  end

  # Get item by barcode
  def item_by_barcode (barcode)
    params = {
      fieldName: 'Barcode',
      fieldValue: barcode,
      owningInstitutions: [ "NYPL" ]
    }
    result = self.search params

    # If no results found, try a dummy record search (incomplete record):
    if result['searchResultRows'].empty?
      params[:deleted] = false
      params[:collectionGroupDesignations] = ['NA']
      params[:catalogingStatus] = 'Incomplete'

      result = self.search params

      $logger.debug "Standard barcode search failed. #{result['searchResultRows'].empty? ? 'Did not find' : 'Found'} record via Dummy search"
    end

    raise ScsbNoMatchError.new(nil), "SCSB returned no match for barcode #{barcode}" if result['searchResultRows'].empty?

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

    raise ScsbError.new(nil), "Error response from SCSB API: statusCode=#{res.code}" if res.code.to_i >= 400

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
