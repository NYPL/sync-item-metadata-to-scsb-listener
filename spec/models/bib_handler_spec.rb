require 'spec_helper'
require 'webmock/rspec'
require 'aws-sdk-kms'

describe BibHandler  do
  varfield_910_rl = { 'marcTag' => '910', 'subfields' => [ { 'tag' => 'a', 'content' => 'RL' } ] }

  before(:each) do
    $logger = NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'] || 'info')

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

    stub_request(:post, "#{ENV['PLATFORM_API_BASE_URL']}recap/sync-item-metadata-to-scsb")
      .to_return(status: 200, body: "{}" )
    stub_request(:post, "#{Base64.strict_decode64 ENV['SCSB_API_BASE_URL']}/searchService/search")
      .with(body: { fieldName: 'OwningInstitutionBibId', fieldValue: '.b10079340x', 'owningInstitutions': ['NYPL'] })
      .to_return(File.new('./spec/fixtures/scsb-api-items-by-bib-id-10079340.raw'))
    stub_request(:post, "#{Base64.strict_decode64 ENV['SCSB_API_BASE_URL']}/searchService/search")
      .with(body: { fieldName: 'OwningInstitutionBibId', fieldValue: '.b114071664', 'owningInstitutions': ['NYPL'] })
      .to_return(File.new('./spec/fixtures/scsb-api-items-by-bib-id-11407166.raw'))
  end

  describe '#should_process?' do
    it "should consider a bib valid for processing if it has a 910|a=RL" do
      expect(BibHandler.should_process?({ 'id' => '10079340', 'varFields' => [ varfield_910_rl ] })).to eq(true)
    end

    it "should consider a bib NOT valid for processing if has anything but 910|a=RL" do
      expect(BibHandler.should_process?({ 'id' => '10079340', 'varFields' => [ 
        { 'marcTag' => '910', 'subfields' => [ { 'tag' => 'a', 'content' => 'BL' } ] }
      ]})).to eq(false)

      expect(BibHandler.should_process?({ 'id' => '10079340', 'varFields' => [ 
        { 'marcTag' => '910', 'subfields' => [ { 'tag' => 'a', 'content' => 'RLOTF' } ] }
      ]})).to eq(false)

      expect(BibHandler.should_process?({ 'id' => '10079340', 'varFields' => [] })).to eq(false)
    end

    it "should not consider a bib valid for processing if it's not mixed and its first item is non-research" do
      expect(BibHandler.should_process?({ 'id' => '20918822' })).to eq(false)
    end

    describe "#should_process?" do
      it "should quietly fail to process any bib for which there are no items" do
        expect(BibHandler.should_process?({ 'id' => 'fakebibid' })).to eq(false)
      end
    end
  end

  describe "#process" do
    before(:each) do
      stub_request(:post, "#{Base64.strict_decode64 ENV['SCSB_API_BASE_URL']}/searchService/search")
        .with(body: { fieldName: 'OwningInstitutionBibId', fieldValue: '.b198227139', 'owningInstitutions': ['NYPL'] })
        .to_return(File.new('./spec/fixtures/scsb-api-items-by-bib-id-b198227139.raw'))
    end

    it "should submit all item barcodes for a valid bib to the sync endpoint" do
      BibHandler.process({ 'id' => '19822713', 'varFields' => [ varfield_910_rl ] })

      expect(a_request(:post, "#{ENV['PLATFORM_API_BASE_URL']}recap/sync-item-metadata-to-scsb")
        .with({
          body: { "user_email" => $notification_email, "barcodes" => [ '33433110812959' ], "source" => "bib-item-store-update"  }
        })
      ).to have_been_made
    end

  end

  it "should submit all item barcodes for a serial bib to the sync endpoint" do
    BibHandler.process({ 'id' => '10079340', 'varFields' => [ varfield_910_rl ]  })

    # This is a serial with 4 items in scsb
    expect(a_request(:post, "#{ENV['PLATFORM_API_BASE_URL']}recap/sync-item-metadata-to-scsb")
      .with({
        body: { "user_email" => $notification_email, "barcodes" => [ '33433020768820', '33433020768838', '33433020768846', '33433020768812' ], "source" => "bib-item-store-update"  }
      })
    ).to have_been_made
  end

  it "should not submit anything if bib determined to be possibly in recap but SCSB returns no items" do
    BibHandler.process({ 'id' => '11407166', 'varFields' => [ varfield_910_rl ]  })

    expect(a_request(:post, "#{ENV['PLATFORM_API_BASE_URL']}recap/sync-item-metadata-to-scsb")
      .with({
        body: { "user_email" => $notification_email, "barcodes" => [ "32101099235572" ], 'owningInstitutions': ['NYPL'], "source" => "bib-item-store-update"  }
      })
    ).to have_not_been_made
  end
end
