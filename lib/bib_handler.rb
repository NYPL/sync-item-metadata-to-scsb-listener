require_relative 'nypl_core'

class BibHandler
  @@mixed_bib_ids = nil

  def self.has_rl_tag? (bib)
    p bib
    return false unless bib['varFields'].is_a?(Array)

    var_field_910 = bib['varFields'].find { |var| var['marcTag'] == '910' }
    return false unless var_field_910
  
    subfield_a = var_field_910['subfields'].find { |sub| sub['tag'] == 'a' }
    return false unless subfield_a

    content = subfield_a['content']
    $logger.debug "910|a for #{bib['id']} is #{content}"

    content == 'RL'
  end

  # Returns true if we should process this bib - either because:
  #  1. it's mixed, which means its first item may or may not be representative
  #     of sibling items, which means we have to *assume* it has recap items
  #  2. its first item has a research Item Type or location, meaning it *may*
  #     be in recap
  def self.should_process? (bib)
    has_rl_tag = has_rl_tag?(bib)
    return true if has_rl_tag

    $logger.info "Refusing to process bib #{bib['id']} because has_rl_tag=#{has_rl_tag}"
    false
  end

  # Evaluate bib to determine if we should process it, and then do so
  def self.process (bib)
    return nil if ! self.should_process? bib

    scsb_barcodes = $scsb_api.barcodes_by_bib_id bib['id']
    if scsb_barcodes.empty?
      $logger.info "No items returned from SCSB for bibid #{bib['id']}"
      return nil
    end

    sync_message = { barcodes: scsb_barcodes, user_email: $notification_email, source: 'bib-item-store-update' }
    $logger.debug "Posting message", sync_message

    resp = $platform_api.post 'recap/sync-item-metadata-to-scsb', sync_message, authenticated: true
    $logger.info "Processed bib #{bib['id']} by posting message", sync_message
  end

end
