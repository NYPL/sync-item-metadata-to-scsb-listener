require 'spec_helper'
require 'webmock/rspec'
require 'aws-sdk-kms'

describe ItemHandler  do
  before(:all) do
    $logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')
  end

  describe '#should_process?' do
    it "should refuse to process invalid item" do
      rc_item = "fladeedle"

      expect(ItemHandler.should_process?(rc_item)).to eq(false)
    end

    it "should refuse to process an item with no location" do
      rc_item = load_fixture 'rc-item.json'

      expect(ItemHandler.should_process?(rc_item.merge({'location' => { 'code' => nil }}))).to eq(false)
      expect(ItemHandler.should_process?(rc_item.merge({'location' => { 'code' => '' }}))).to eq(false)
      expect(ItemHandler.should_process?(rc_item.merge({'location' => nil}))).to eq(false)
    end

    it "should refuse to process an item with no barcode" do
      rc_item = load_fixture 'rc-item.json'

      expect(ItemHandler.should_process?(rc_item.merge({'barcode' => nil}))).to eq(false)
      expect(ItemHandler.should_process?(rc_item.merge({'barcode' => ''}))).to eq(false)
    end

    it "should consider an item with a rc location valid for processing" do
      rc_item = load_fixture 'rc-item.json'

      expect(ItemHandler.should_process?(rc_item)).to eq(true)
    end

    it "should consider an item without a rc location invalid for processing" do
      rc_item = load_fixture 'non-rc-item.json'

      expect(ItemHandler.should_process?(rc_item)).to eq(false)
    end

    it "should return false for deleted item" do
      deleted_item = load_fixture 'deleted-item.json'

      expect(ItemHandler.should_process?(deleted_item)).to eq(false)
    end
  end

  describe '#padded_bnum_for_sierra_item' do
    it 'should compute padded bib id' do
      expect(ItemHandler.padded_bnum_for_sierra_item({ 'bibIds' => [ '1234' ] })).to eq('b12348')
    end
  end

  describe '#is_incomplete_record' do
    it 'should identify Incomplete record' do
      expect(ItemHandler.is_incomplete_record({ 'title' => 'Dummy Title' })).to eq(true)
    end

    it 'should identify Complete record' do
      expect(ItemHandler.is_incomplete_record({ 'title' => 'Fair to Middling Title' })).to eq(false)
    end
  end

  describe '#item_bnum_mismatch' do
    it 'should return false for matching bib identifiers' do
      expect(ItemHandler.item_bnum_mismatch({ 'bibIds' => [ '1234' ] }, { 'owningInstitutionBibId' => '.b12348' })).to eq(false)
      expect(ItemHandler.item_bnum_mismatch({ 'bibIds' => [ '1234', 'multiple-bib-ids-are-meaningless-here' ] }, { 'owningInstitutionBibId' => '.b12348' })).to eq(false)
    end

    it 'should return true for mis-matched bib identifiers' do
      expect(ItemHandler.item_bnum_mismatch({ 'bibIds' => [ '1234' ] }, { 'owningInstitutionBibId' => '.b5678' })).to eq(true)
      # The actual bib number agree here, but the sierra mod11 check digit in
      # the scsb_item is not what we expect:
      expect(ItemHandler.item_bnum_mismatch({ 'bibIds' => [ '1234' ] }, { 'owningInstitutionBibId' => '.b1234x' })).to eq(true)
    end
  end

  describe '#process' do
    before(:each) do

      kms = Aws::KMS::Client.new(region: 'us-east-1', stub_responses: true)
      kms.stub_responses(:decrypt, -> (context) {
        'foo'
      })
      ENV['PLATFORM_API_BASE_URL'] = 'https://example.com/api/v0.1/'
      ENV['NYPL_OAUTH_ID'] = Base64.strict_encode64 'fake-client'
      ENV['NYPL_OAUTH_SECRET'] = Base64.strict_encode64 'fake-secret'
      ENV['NYPL_OAUTH_URL'] = 'https://isso.example.com/'

      ENV['SCSB_API_KEY'] = Base64.strict_encode64 'fake-key-encrypted'
      ENV['SCSB_API_BASE_URL'] = Base64.strict_encode64 'https://example.com'

      KmsClient.aws_kms_client.stub_responses(:decrypt, -> (context) {
        # "Decrypt" by subbing "encrypted" with "decrypted" in string:
        { plaintext: context.params[:ciphertext_blob].gsub('encrypted', 'decrypted') }
      })

      $platform_api = PlatformApiClient.new
      $scsb_api = ScsbClient.new
      $notification_email = 'user@example.com'

      stub_request(:post, "#{ENV['NYPL_OAUTH_URL']}oauth/token").to_return(status: 200, body: '{ "access_token": "fake-access-token" }')
      stub_request(:post, "#{ENV['PLATFORM_API_BASE_URL']}recap/sync-item-metadata-to-scsb")
        .to_return(status: 200, body: "{}" )

      stub_request(:post, "#{Base64.strict_decode64 ENV['SCSB_API_BASE_URL']}/searchService/search")
        .with(body: { fieldName: 'Barcode', fieldValue: '33433020768812', 'owningInstitutions': ['NYPL'] })
        .to_return(File.new('./spec/fixtures/scsb-api-items-by-barcode-33433020768812.raw'))

      stub_request(:post, "#{Base64.strict_decode64 ENV['SCSB_API_BASE_URL']}/searchService/search")
        .with(body: { fieldName: 'Barcode', fieldValue: '33433014464741', 'owningInstitutions': ['NYPL'] })
        .to_return(File.new('./spec/fixtures/scsb-api-items-by-barcode-33433014464741.raw'))

      stub_request(:post, "#{Base64.strict_decode64 ENV['SCSB_API_BASE_URL']}/searchService/search")
        .with(body: { fieldName: 'Barcode', fieldValue: '33433074008073', 'owningInstitutions': ['NYPL'] })
        .to_return(File.new('./spec/fixtures/scsb-api-items-by-barcode-33433074008073.raw'))
      stub_request(:post, "#{Base64.strict_decode64 ENV['SCSB_API_BASE_URL']}/searchService/search")
        .with(body: { fieldName: 'Barcode', fieldValue: '33433074008073', 'owningInstitutions': ['NYPL'],
          'deleted': false, 'collectionGroupDesignations': ["NA"], 'catalogingStatus': "Incomplete" })
        .to_return(File.new('./spec/fixtures/scsb-api-items-by-barcode-33433074008073-dummy.raw'))

      # Complete record search for 33433068445950:
      stub_request(:post, "#{Base64.strict_decode64 ENV['SCSB_API_BASE_URL']}/searchService/search")
        .with(body: { fieldName: 'Barcode', fieldValue: '33433068445950', 'owningInstitutions': ['NYPL'] })
        .to_return(File.new('./spec/fixtures/scsb-api-items-by-barcode-33433068445950.raw'))
      # Incomplete record search for 33433068445950:
      stub_request(:post, "#{Base64.strict_decode64 ENV['SCSB_API_BASE_URL']}/searchService/search")
        .with(body: { fieldName: 'Barcode', fieldValue: '33433068445950', 'owningInstitutions': ['NYPL'],
          'deleted': false, 'collectionGroupDesignations': ["NA"], 'catalogingStatus': "Incomplete"
        })
        .to_return(File.new('./spec/fixtures/scsb-api-items-by-barcode-33433068445950-dummy.raw'))
    end

    it "should handle a serial item" do
      item = load_fixture 'item-11907242.json'

      # This barcode will match a serial bib with owningInstitutionBibId ".b10079340x",
      # which has four nested items, of which this barcode is the last.
      ItemHandler.process item

      # This is a serial with 4 items in scsb
      expect(a_request(:post, "#{ENV['PLATFORM_API_BASE_URL']}recap/sync-item-metadata-to-scsb")
        .with({
          body: { "user_email" => $notification_email, "barcodes" => [ '33433020768812' ], "source" => "bib-item-store-update" }
        })
      ).to have_been_made
    end

    it "should handle a serial item transfer" do
      item = load_fixture 'item-11907242.json'
      item['bibIds'] = ['1234']

      # This barcode will match a serial bib with owningInstitutionBibId ".b10079340x",
      # which has four nested items, of which this barcode is the last.
      ItemHandler.process item

      # This is a serial with 4 items in scsb
      expect(a_request(:post, "#{ENV['PLATFORM_API_BASE_URL']}recap/sync-item-metadata-to-scsb")
        .with({
          body: { "user_email" => $notification_email, "barcodes" => [ '33433020768812' ], "action" => 'transfer', "bib_record_number" => 'b12348', "source" => "bib-item-store-update"  }
        })
      ).to have_been_made
    end

    it "should handle a non-serial item update" do
      item = load_fixture 'item-10093494.json'

      # This barcode will match a bib with a single item
      ItemHandler.process item

      expect(a_request(:post, "#{ENV['PLATFORM_API_BASE_URL']}recap/sync-item-metadata-to-scsb")
        .with({
          body: { "user_email" => $notification_email, "barcodes" => [ '33433014464741' ], "source" => "bib-item-store-update"  }
        })
      ).to have_been_made
    end

    it "should handle a non-serial item transfer" do
      item = load_fixture 'item-10093494.json'
      item['bibIds'] = ['1234']

      # This barcode will match a bib with a single item
      ItemHandler.process item

      expect(a_request(:post, "#{ENV['PLATFORM_API_BASE_URL']}recap/sync-item-metadata-to-scsb")
        .with({
          body: { "user_email" => $notification_email, "barcodes" => [ '33433014464741' ], "action" => 'transfer', "bib_record_number" => 'b12348', "source" => "bib-item-store-update"  }
        })
      ).to have_been_made
    end

    it "should no-op an item that is not in scsb" do
      # This is an item (barcode 33433074008073) that doesn't exist in scsb:
      item = load_fixture 'item-36845773.json'

      # This will trigger the ItemHandler to look up the item in scsb, which
      # will fail both Complete and Incomplete record queries, causing
      # nothing to be posted to the /sync-item-metadata-to-scsb:
      ItemHandler.process item

      expect(a_request(:post, "#{ENV['PLATFORM_API_BASE_URL']}recap/sync-item-metadata-to-scsb")).to have_not_been_made
    end

    it "should process an Incomplete item as an update" do
      # barcode 33433068445950:
      item = load_fixture 'item-15496371.json'

      # This barcode will match a dummy record in SCSB search:
      ItemHandler.process item

      expect(a_request(:post, "#{ENV['PLATFORM_API_BASE_URL']}recap/sync-item-metadata-to-scsb")
        .with({
          body: { "user_email" => $notification_email, "barcodes" => [ '33433068445950' ], "source" => "bib-item-store-update"  }
        })
      ).to have_been_made
    end
  end
end
