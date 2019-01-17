require_relative 'custom_logger'
require_relative 'nypl_core'

class BibHandler
  @@mixed_bib_ids = nil

  # Get the first item associated with the given bib id from ItemService
  def self.first_item_by_bib_id (id) 
    # Note that we'd like to pass `&limit=1` here, but ItemService seems to
    # have a bug ( https://github.com/NYPL-discovery/itemservice/issues/5 )
    items = $platform_api.get "items?nyplSource=sierra-nypl&bibId=#{id}"
    if (items.nil? || items.empty? || items['data'].nil? || !items['data'].is_a?(Array))
      CustomLogger.error "Bad response from ItemService querying for first item by bib id #{id}", items
      nil
    else
      items['data'][0]
    end
  end

  # Determine if the first item of the given bib is a Research item
  def self.first_item_is_research? (bib)
    CustomLogger.debug "Fetching first item for bib #{bib['id']}"

    first_item = first_item_by_bib_id bib['id']

    CustomLogger.debug "Got first item for bib #{bib['id']}", first_item

    # Check the two relevant scenarios that obligate the item to be Research:
    item_has_research_item_type?(first_item) || item_has_research_location?(first_item)
  end

  # Return true if item's "catalog item type" identifies it as Research
  # Based on https://github.com/NYPL-discovery/discovery-store-poster/blob/33baaad06dd73f45089bb780dbb4afd5a13e2204/lib/models/item-sierra-record.js#L40-L47
  def self.item_has_research_item_type? (item)
    raise "Error parsing item: no fixedFields" if item['fixedFields'].nil?
    raise "Error parsing item: invalid fixedFields" if ! item['fixedFields'].is_a?(Hash)

    item_type = item['fixedFields'].values.select { |field| field['label'] == 'Item Type' }.pop
    item_type = item_type['value'] if ! item_type.nil? && item_type.is_a?(Hash) && item_type['value'].is_a?(String)

    mapped_item_type = $nypl_core.by_catalog_item_type[item_type]

    mapped_item_type_is_research = mapped_item_type.is_a?(Hash) && mapped_item_type['collectionType'].is_a?(Array) && mapped_item_type['collectionType'].include?('Research')

    CustomLogger.debug "Calculating item_has_research_item_type=#{mapped_item_type_is_research}", { item_type: item_type, mapped_item_type: mapped_item_type }

    mapped_item_type_is_research
  end

  # Return true if item's location has *only* "Research" materials
  # Based on https://github.com/NYPL-discovery/discovery-store-poster/blob/33baaad06dd73f45089bb780dbb4afd5a13e2204/lib/models/item-sierra-record.js#L30-L38
  def self.item_has_research_location? (item)
    # Determine collection type of first item:
    mapped_location = $nypl_core.by_sierra_location[item['location']['code']]
    holding_location_collection_type = nil
    holding_location_collection_type = mapped_location['collectionTypes'][0] if mapped_location.is_a?(Hash) && mapped_location['collectionTypes'] && mapped_location['collectionTypes'] == 1

    CustomLogger.debug "Calculating holding location collection type as #{mapped_location['collectionTypes'][0]}", { location_code: item['location']['code'], mapped_location: mapped_location }

    holding_location_collection_type === 'Research'
  end

  # Return true if given bib has been identified as a "mixed bib"
  def self.is_mixed_bib? (bib)
    if @@mixed_bib_ids.nil?
      @@mixed_bib_ids = File.read('data/mixed-bibs.csv')
        .split("\n")
        .map { |bnum| bnum.strip.sub(/^b/, '') }

      CustomLogger.debug "Loaded #{@@mixed_bib_ids.size} mixed bib ids"
    end

    is_mixed_bib = @@mixed_bib_ids.include? bib['id']
    CustomLogger.debug "Determined is_mixed_bib=#{is_mixed_bib} for #{bib['id']}"

    is_mixed_bib
  end

  # Returns true if we should process this bib - either because:
  #  1. it's mixed, which means its first item may or may not be representative
  #     of sibling items, which means we have to *assume* it has recap items
  #  2. its first item has a research Item Type or location, meaning it *may*
  #     be in recap
  def self.should_process? (bib)
    is_mixed = is_mixed_bib?(bib)
    return true if is_mixed

    first_item_research = first_item_is_research?(bib)
    return true if first_item_research

    CustomLogger.info "Refusing to process bib #{bib['id']} because is_mixed=#{is_mixed}, first_item_research=#{first_item_research}"
    false
  end

  # Evaluate bib to determine if we should process it, and then do so
  def self.process (bib)
    return nil if ! self.should_process? bib

    scsb_items = $scsb_api.items_by_bib_id bib['id']
    raise "Could not retrieve bib from scsb by id", { id: bib['id'] } if scsb_items.nil?

    sync_message = { barcodes: scsb_items.map { |item| item['barcode'] }, user_email: $notification_email }
    CustomLogger.debug "Posting message", sync_message

    resp = $platform_api.post 'recap/sync-item-metadata-to-scsb', sync_message, authenticated: true
    CustomLogger.info "Processed bib #{bib['id']} by posting message", sync_message
  end

end
