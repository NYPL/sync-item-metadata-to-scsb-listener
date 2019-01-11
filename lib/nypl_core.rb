require 'open-uri'

class NyplCore
  def initialize
    @mappings = {}
  end

  def by_sierra_location
    self._by_mapping('by_sierra_location.json')
  end

  def by_catalog_item_type
    self._by_mapping('by_catalog_item_type.json')
  end

  def _by_mapping (mapping_file)
    @mappings[mapping_file] = JSON.parse(open("https://s3.amazonaws.com/nypl-core-objects-mapping-production/#{mapping_file}").read) if @mappings[mapping_file].nil?
    @mappings[mapping_file]
  end
end
