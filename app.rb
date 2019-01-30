require 'nypl_log_formatter'

require_relative 'lib/avro_decoder'
require_relative 'lib/scsb_client'
require_relative 'lib/platform_api_client'
require_relative 'lib/kms_client'
require_relative 'lib/item_handler'
require_relative 'lib/bib_handler'

def init
  $avro_decoders = {
    "Bib" => AvroDecoder.by_name('Bib'),
    "Item" => AvroDecoder.by_name('Item')
  }

  $scsb_api = ScsbClient.new

  $platform_api = PlatformApiClient.new

  $notification_email = KmsClient.new.decrypt ENV['NOTIFICATION_EMAIL']

  $nypl_core = NyplCore.new

  $logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')
end

def handle_event(event:, context:)
  init

  event["Records"]
    .select { |record| record["eventSource"] == "aws:kinesis" }
    .each do |record|
      avro_data = record["kinesis"]["data"]

      # Determine what schema to use based on eventSourceARN:
      # ARN will end in a phrase like 'Bib-production', or 'BibBulk-production'
      schema_name = record["eventSourceARN"].split('/').last.sub(/(Bulk)?(-.*)?$/, '')
      raise "Unrecognized schema: #{schema_name}. Must be one of #{$avro_decoders.keys.join(', ')}" if ! $avro_decoders.keys.include? schema_name

      decoded = $avro_decoders[schema_name].decode avro_data
      $logger.debug "Decoded #{schema_name}", decoded

      ItemHandler.process decoded if schema_name == 'Item'
      BibHandler.process decoded if schema_name == 'Bib'
    end

  nil
end
