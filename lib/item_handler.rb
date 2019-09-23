require_relative 'sierra_mod_11'

class ItemHandler
  def self.should_process? (item)
    # Make sure item meets minimum format & property requirements:
    if ! item.is_a?(Hash)
      $logger.debug 'Refusing to process invalid item', item: item
      return false
    end

    if ! item['location'].is_a?(Hash) || !item['location']['code'].is_a?(String) || item['location']['code'].empty?
      $logger.debug 'Refusing to process item with no location', item: item
      return false
    end

    if ! item['barcode'].is_a?(String) || item['barcode'].empty?
      $logger.debug 'Refusing to process item with no barcode', item: item
      return false
    end

    if item["location"]["code"].match(/^rc/).nil?
      $logger.debug 'Refusing to process item with non-recap location', { location: item["location"]["code"], itemId: item['id'] }
      return false
    end

    true
  end

  # Given a sierraitem (Hash), returns the padded form ('b' prefix + mod11 suffix)
  def self.padded_bnum_for_sierra_item (sierra_item)
    "b#{SierraMod11.mod11(sierra_item['bibIds'].first)}"
  end

  # Return true if bibId in sierra_item mismatched with owningInstitutionBibId
  # in scsb_item
  def self.item_bnum_mismatch (sierra_item, scsb_item)
    # Does item bnum disagree with scsb bnum?
    # Strip ".b" prefix and sierra mod11 check digit
    scsb_bnum = scsb_item['owningInstitutionBibId']
    padded_bnum = self.padded_bnum_for_sierra_item sierra_item
    mismatched = scsb_bnum != ".#{padded_bnum}"

    $logger.debug "Detecting bnum discrepancy: mismatched=#{mismatched}", { scsb_bnum: scsb_bnum, local_bnum_with_padding: padded_bnum, local_bnum: sierra_item['bibIds'].first, mismatched: mismatched }

    mismatched
  end

  def self.is_incomplete_record (scsb_item)
    is_incomplete = scsb_item['title'] == 'Dummy Title'
    $logger.debug "Detecting incomplete item", { barcode: scsb_item['barcode'], is_incomplete: is_incomplete, title: scsb_item['title'] }
    is_incomplete
  end

  def self.process (item)
    return nil if ! self.should_process? item

    begin
      scsb_item = $scsb_api.item_by_barcode item['barcode']

    # Catch specific error thrown when barcode doesn't match:
    rescue ScsbNoMatchError => e
      $logger.info "Could not retrieve item from scsb by barcode", { barcode: item['barcode'], itemId: item['id'] }
      return
    end

    sync_message = { barcodes: [ item['barcode'] ], user_email: $notification_email, source: 'bib-item-store-update' }

    # Determine if the sync job is a transfer by checking both:
    #  - bnum is different in ItemService compared with SCSB
    #  - SCSB item is not Incomplete (which willappear as a bnum mismatch
    #    because scsb Incomplete bnums are temporary)
    if self.item_bnum_mismatch(item, scsb_item) && ! self.is_incomplete_record(scsb_item)
      sync_message[:action] = 'transfer'
      sync_message[:bib_record_number] = self.padded_bnum_for_sierra_item item

      $logger.info "Determined update is a transfer from #{scsb_item['owningInstitutionBibId']} to #{sync_message[:bib_record_number]}", { barcode: item['barcode'] }
    end

    $logger.debug "Posting message", sync_message

    resp = $platform_api.post 'recap/sync-item-metadata-to-scsb', sync_message, authenticated: true
    $logger.info "Processed item #{item['id']} by posting message", sync_message
  end

end
