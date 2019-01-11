require 'json'

require_relative '../lib/item_handler'
require_relative '../lib/bib_handler'

def load_fixture (file)
  JSON.parse File.read("./spec/fixtures/#{file}")
end
