require 'json'

require_relative '../lib/item_handler'
require_relative '../lib/bib_handler'
require_relative '../lib/avro_decoder'
require_relative '../lib/platform_api_client'
require_relative '../lib/kms_client'

def load_fixture (file)
  JSON.parse File.read("./spec/fixtures/#{file}")
end
