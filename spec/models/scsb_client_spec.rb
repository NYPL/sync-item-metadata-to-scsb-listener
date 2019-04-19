require 'spec_helper'
require 'webmock/rspec'

describe ScsbClient do
  before(:each) do

    ENV['SCSB_API_KEY'] = Base64.strict_encode64 'fake-key-encrypted'
    ENV['SCSB_API_BASE_URL'] = Base64.strict_encode64 'https://example.com'

    KmsClient.aws_kms_client.stub_responses(:decrypt, -> (context) {
      # "Decrypt" by subbing "encrypted" with "decrypted" in string:
      { plaintext: context.params[:ciphertext_blob].gsub('encrypted', 'decrypted') }
    })

    $logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')

    stub_request(:post, "#{Base64.strict_decode64 ENV['SCSB_API_BASE_URL']}/searchService/search")
      .with(body: { fieldName: 'OwningInstitutionBibId', fieldValue: '.b10079340x', 'owningInstitutions': ['NYPL'] })
      .to_return(File.new('./spec/fixtures/scsb-api-items-by-bib-id-10079340.raw'))

    stub_request(:post, "#{Base64.strict_decode64 ENV['SCSB_API_BASE_URL']}/searchService/search")
      .with(body: { fieldName: 'Barcode', fieldValue: '33433020768838', 'owningInstitutions': ['NYPL'] })
      .to_return(File.new('./spec/fixtures/scsb-api-items-by-barcode-33433020768838.raw'))

    # Stub request for Incomplete record scoped *incorrectly*:
    stub_request(:post, "#{Base64.strict_decode64 ENV['SCSB_API_BASE_URL']}/searchService/search")
      .with(body: { fieldName: 'Barcode', fieldValue: '33433121644334', 'owningInstitutions': ['NYPL'] })
      .to_return(File.new('./spec/fixtures/scsb-api-items-by-barcode-33433121644334.raw'))
    # Stub request for Incomplete record scoped *correctly*:
    stub_request(:post, "#{Base64.strict_decode64 ENV['SCSB_API_BASE_URL']}/searchService/search")
      .with(body: {
        fieldName: 'Barcode', fieldValue: '33433121644334', 'owningInstitutions': ['NYPL'],
        deleted: false, collectionGroupDesignations: ['NA'], catalogingStatus: 'Incomplete'
      })
      .to_return(File.new('./spec/fixtures/scsb-api-items-by-barcode-33433121644334-dummy.raw'))
  end

  describe '#items_by_bib_id' do
    it "should handle scsb api response for matched bib id" do
      client = ScsbClient.new

      items = client.items_by_bib_id('10079340')
      expect(items).to be_a(Array)
      expect(items.size).to eq(1)
      expect(items[0]).to be_a(Object)
      expect(items[0]['owningInstitutionBibId']).to eq('.b10079340x')
      expect(items[0]['searchItemResultRows']).to be_a(Array)
      expect(items[0]['searchItemResultRows'].size).to eq(4)
    end
  end

  describe '#barcodes_by_bib_id' do
    it "should identify all barcodes for matched serial bib id" do
      client = ScsbClient.new

      barcodes = client.barcodes_by_bib_id('10079340')
      expect(barcodes).to be_a(Array)
      expect(barcodes.size).to eq(4)
      expect(barcodes).to include("33433020768820", "33433020768838", "33433020768846", "33433020768812")
    end
  end

  describe '#items_by_barcode' do
    it "should parse scsb api response for item by barcode" do
      client = ScsbClient.new

      item = client.item_by_barcode('33433020768838')
      expect(item).to be_a(Object)
      expect(item['searchItemResultRows']).to be_a(Array)
      expect(item['searchItemResultRows'].size).to eq(1)
      expect(item['searchItemResultRows'][0]).to be_a(Object)
      expect(item['searchItemResultRows'][0]['owningInstitutionItemId']).to eq('.i119072440')

      # Confirm http call was made with api key:
      decoded_base_url = Base64.strict_decode64 ENV['SCSB_API_BASE_URL']
      decrypted_api_key = 'fake-key-decrypted'

      expect(a_request(:post, "#{decoded_base_url}/searchService/search").
         with({
          body: { "fieldName" => "Barcode", "fieldValue": "33433020768838", "owningInstitutions": ['NYPL'] },
          headers: {'Content-Type' => 'application/json', 'api_key': 'fake-key-decrypted'}
        })
      ).to have_been_made
    end

    it "should fallback on Dummy search for incomplete record", dev: true do
      client = ScsbClient.new

      item = client.item_by_barcode('33433121644334')
      expect(item).to be_a(Object)
      expect(item['bibId']).to eq(9303702)
      expect(item['title']).to eq('Dummy Title')
      expect(item['author'].strip).to eq('Dummy Author')
      expect(item['owningInstitutionItemId']).to eq('d63420')

      # Confirm http call was made with api key:
      decoded_base_url = Base64.strict_decode64 ENV['SCSB_API_BASE_URL']
      decrypted_api_key = 'fake-key-decrypted'

      # Expect two SCSB requests to have been made:
      # 1. An initial, standard query for a complete record (which fails):
      expect(a_request(:post, "#{decoded_base_url}/searchService/search").
         with({
          body: { "fieldName" => "Barcode", "fieldValue": "33433121644334", "owningInstitutions": ['NYPL'] },
          headers: {'Content-Type' => 'application/json', 'api_key': 'fake-key-decrypted'}
        })
      ).to have_been_made

      # .. And 2) a query scoped to match Incomplete records:
      expect(a_request(:post, "#{decoded_base_url}/searchService/search").
         with({
          body: {
            "fieldName" => "Barcode", "fieldValue": "33433121644334", "owningInstitutions": ['NYPL'],
            "deleted": false, "collectionGroupDesignations": ['NA'], "catalogingStatus": 'Incomplete'
          },
          headers: {'Content-Type' => 'application/json', 'api_key': 'fake-key-decrypted'}
        })
      ).to have_been_made
    end
  end
end
