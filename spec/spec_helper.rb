require 'json'
require 'nypl_log_formatter'

require_relative '../lib/item_handler'
require_relative '../lib/bib_handler'
require_relative '../lib/avro_decoder'
require_relative '../lib/platform_api_client'
require_relative '../lib/kms_client'
require_relative '../lib/scsb_client'
require_relative '../lib/sierra_mod_11'

ENV['LOG_LEVEL'] = 'error'
ENV['APP_ENV'] = 'test'

def load_fixture (file)
  JSON.parse File.read("./spec/fixtures/#{file}")
end
