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

    stub_request(:post, "#{Base64.strict_decode64 ENV['SCSB_API_BASE_URL']}/searchService/search")
      .with(body: { fieldName: 'OwningInstitutionBibId', fieldValue: '.b10079340x' })
      .to_return(File.new('./spec/fixtures/scsb-api-items-by-bib-id-10079340.raw'))

    stub_request(:post, "#{Base64.strict_decode64 ENV['SCSB_API_BASE_URL']}/searchService/search")
      .with(body: { fieldName: 'Barcode', fieldValue: '33433020768838' })
      .to_return(File.new('./spec/fixtures/scsb-api-items-by-bib-id-10079340.raw'))
  end

  it "should parse scsb api response for items by bib id" do
    client = ScsbClient.new

    items = client.items_by_bib_id('10079340')
    expect(items).to be_a(Array)
    expect(items.size).to eq(1)
    expect(items[0]).to be_a(Object)
    expect(items[0]['owningInstitutionBibId']).to eq('10079340')
    expect(items[0]['owningInstitutionItemId']).to eq('7532161')
  end

  it "should parse scsb api response for item by barcode" do
    client = ScsbClient.new

    item = client.item_by_barcode('33433020768838')
    expect(item).to be_a(Object)
    expect(item['owningInstitutionItemId']).to eq('7532161')

    # Confirm http call was made with api key:
    decoded_base_url = Base64.strict_decode64 ENV['SCSB_API_BASE_URL']
    decrypted_api_key = 'fake-key-decrypted'

    expect(a_request(:post, "#{decoded_base_url}/searchService/search").
       with({
        body: { "fieldName" => "Barcode", "fieldValue": "33433020768838" },
        headers: {'Content-Type' => 'application/json', 'api_key': 'fake-key-decrypted'}
      })
    ).to have_been_made
  end
end
