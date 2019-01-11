require_relative 'custom_logger'

class ItemHandler
  def self.should_process? (item)
    is_recap = ! item["location"]["code"].match(/^rc/).nil?

    CustomLogger.debug('Skipping item with non-recap location', { location: item["location"]["code"], itemId: item['id'] }) if ! is_recap

    is_recap
  end

  def self.process (item)
    return nil if ! self.should_process? item

    scsb_item = $scsb_api.item_by_barcode item['barcode']
    raise "Could not retrieve item from scsb by barcode", { barcode: item['barcode'], itemId: item['id'] } if scsb_item.nil?

    sync_message = { barcodes: [ item['barcode'] ], user_email: $notification_email }
    CustomLogger.debug "Posting message", sync_message

    resp = $platform_api.post 'recap/sync-item-metadata-to-scsb', sync_message, authenticated: true
    CustomLogger.info "Posted message", sync_message
  end

end
