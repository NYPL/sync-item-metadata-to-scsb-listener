require 'spec_helper'
require 'webmock/rspec'
require 'aws-sdk-kms'

describe BibHandler  do

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
    $nypl_core = NyplCore.new
    $scsb_api = ScsbClient.new
    $notification_email = 'user@example.com'

    stub_request(:post, "#{ENV['NYPL_OAUTH_URL']}oauth/token").to_return(status: 200, body: '{ "access_token": "fake-access-token" }')

    stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}items?nyplSource=sierra-nypl&bibId=10079340")
      .to_return(File.new("./spec/fixtures/platform-api-items-by-bib-10079340.raw"))
    stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}items?nyplSource=sierra-nypl&bibId=20918822")
      .to_return(File.new("./spec/fixtures/platform-api-items-by-bib-20918822.raw"))
    stub_request(:get, "https://s3.amazonaws.com/nypl-core-objects-mapping-production/by_catalog_item_type.json")
      .to_return(status: 200, body: File.read('./spec/fixtures/by_catalog_item_type.json')) 
    stub_request(:get, "https://s3.amazonaws.com/nypl-core-objects-mapping-production/by_sierra_location.json")
      .to_return(status: 200, body: File.read('./spec/fixtures/by_sierra_location.json')) 
    stub_request(:post, "#{ENV['PLATFORM_API_BASE_URL']}recap/sync-item-metadata-to-scsb")
      .to_return(status: 200, body: "{}" )
    stub_request(:post, "#{Base64.strict_decode64 ENV['SCSB_API_BASE_URL']}/searchService/search")
      .with(body: { fieldName: 'OwningInstitutionBibId', fieldValue: '10079340' })
      .to_return(File.new('./spec/fixtures/scsb-api-items-by-bib-id-10079340.raw'))
  end

  it "should load mixed bibs lookup" do
    expect(BibHandler.is_mixed_bib?({ 'id' => '100000885' })).to eq(true)
    expect(BibHandler.is_mixed_bib?({ 'id' => 'fladeedle' })).to eq(false)
  end

  it "should query first item by bib id" do
    first_item = BibHandler.first_item_by_bib_id('10079340')
    expect(first_item).to be_a(Object)
    expect(first_item['id']).to eq('11907245')
  end

  it "should identify item with research Item Type as research" do
    item_type = "3"
    is_research = BibHandler.item_has_research_item_type?({ "fixedFields" => { "0" => { "label" => "Item Type", "value" => item_type } } })
    expect(is_research).to eq(true)
  end

  it "should identify item with non-research Item Type as non-research" do
    item_type = "138"
    is_research = BibHandler.item_has_research_item_type?({ "fixedFields" => { "0" => { "label" => "Item Type", "value" => item_type } } })
    expect(is_research).to eq(false)
  end

  it "should identify item with non-research location as non-research" do
    is_research = BibHandler.item_has_research_item_type?({ "location" => { "code" => "hfa0f" }, "fixedFields" => {} })
    expect(is_research).to eq(false)
  end

  it "should identify item with non-research location as non-research" do
    is_research = BibHandler.item_has_research_item_type?({ "location" => { "code" => "rc2ma" }, "fixedFields" => {} })
    expect(is_research).to eq(false)
  end

  it "should identify first item as research" do
    is_research = BibHandler.first_item_is_research?({ "id" => "10079340" })
    expect(is_research).to eq(true)
  end

  it "should identify first item as non-research" do
    # this item has non-research Item Type:
    is_research = BibHandler.first_item_is_research?({ "id" => "20918822" })
    expect(is_research).to eq(false)
  end

  it "should consider a bib valid for processing if it is mixed" do
    expect(BibHandler.should_process?({ 'id' => '100000885' })).to eq(true)
  end

  it "should consider a bib valid for processing if its first item is research" do
    expect(BibHandler.should_process?({ 'id' => '10079340' })).to eq(true)
  end

  it "should not consider a bib valid for processing if it's not mixed and its first item is non-research" do
    expect(BibHandler.should_process?({ 'id' => '20918822' })).to eq(false)
  end

  it "should submit all item barcodes for a valid bib to the sync endpoint" do
    BibHandler.process({ 'id' => '10079340' })

    expect(a_request(:post, "#{ENV['PLATFORM_API_BASE_URL']}recap/sync-item-metadata-to-scsb")
      .with({
        body: { "user_email" => $notification_email, "barcodes" => [ "32101099235572" ] }
      })
    ).to have_been_made
  end
end
