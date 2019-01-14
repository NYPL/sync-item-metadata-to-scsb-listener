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

    $platform_api = PlatformApiClient.new

    raw_response_file = File.new("./spec/fixtures/platform-api-items-by-bib-10079340.raw")
    stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}items?nyplSource=sierra-nypl&bibId=10079340&limit=1").to_return(raw_response_file)
  end

  it "should load mixed bibs lookup" do
    expect(BibHandler.is_mixed_bib?({ 'id' => '100000885' })).to eq(true)
    expect(BibHandler.is_mixed_bib?({ 'id' => 'fladeedle' })).to eq(false)
  end
=begin

  it "should query first item by bib id" do
    first_item = first_item_by_bib_id(10079340)
    expect(first_item).to be_a(Object)
    expect(first_item['id']).to eq('11907245')
  end

  it "should consider a bib valid for processing" do
    bib = load_fixture 'bib.json'

    
    # expect(BibHandler.should_process?(bib)).to eq(true)
  end
=end
end
