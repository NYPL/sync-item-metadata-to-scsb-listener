# require 'lib/errors'

require_relative 'lib/avro_decoder'
require_relative 'lib/custom_logger'
require_relative 'lib/scsb_client'
require_relative 'lib/platform_api_client'
require_relative 'lib/kms_client'

def init
  $avro_decoders = {
    "Bib" => AvroDecoder.by_name('Bib'),
    "Item" => AvroDecoder.by_name('Item')
  }

  $scsb_api = ScsbClient.new

  $platform_api = PlatformApiClient.new

  $notification_email = KmsClient.new.decrypt ENV['NOTIFICATION_EMAIL']
end

def handle_item (item)
  if ! item["location"]["code"].match /^rc/
    CustomLogger.info('Skipping item with non-recap location', { location: item["location"]["code"], itemId: item['id'] })

  else
    scsb_item = $scsb_api.item_by_barcode item['barcode']
    raise "Could not retrieve item from scsb by barcode", { barcode: item['barcode'], itemId: item['id'] } if scsb_item.nil?

    sync_message = { barcodes: [ item['barcode'] ], user_email: $notification_email }
    CustomLogger.debug "Posting message", sync_message

    resp = $platform_api.post 'recap/sync-item-metadata-to-scsb', sync_message, authenticated: true
    CustomLogger.info "Posted message", sync_message

    { success: true }
  end
end

def handle_event(event:, context:)
  init

  event["Records"]
    .select { |record| record["eventSource"] == "aws:kinesis" }
    .each do |record|
      avro_data = record["kinesis"]["data"]

      # Determine what schema to use based on eventSourceARN:
      schema_name = record["eventSourceARN"].split('/').last
      raise "Unrecognized schema: #{schema_name}. Must be one of #{$avro_decoders.keys.join(', ')}" if ! $avro_decoders.keys.include? schema_name

      decoded = $avro_decoders[schema_name].decode avro_data

      handle_item decoded if schema_name == 'Item'
      handle_bib decoded if schema_name == 'Bib'
    end
end
