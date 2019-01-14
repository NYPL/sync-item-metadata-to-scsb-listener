require 'spec_helper'
require 'webmock/rspec'
require 'aws-sdk-kms'

describe PlatformApiClient do
  before(:each) do
    ENV['PLATFORM_API_BASE_URL'] = 'https://example.com/api/v0.1/'
    ENV['NYPL_OAUTH_ID'] = Base64.strict_encode64 'fake-client'
    ENV['NYPL_OAUTH_SECRET'] = Base64.strict_encode64 'fake-secret'
    ENV['NYPL_OAUTH_URL'] = 'https://isso.example.com/'

    KmsClient.aws_kms_client.stub_responses(:decrypt, -> (context) {
      # "Decrypt" by subbing "encrypted" with "decrypted" in string:
      { plaintext: context.params[:ciphertext_blob].gsub('encrypted', 'decrypted') }
    })


    stub_request(:post, "#{ENV['NYPL_OAUTH_URL']}oauth/token").to_return(status: 200, body: '{ "access_token": "fake-access-token" }')
    stub_request(:get, "#{ENV['PLATFORM_API_BASE_URL']}bibs/sierra-nypl/b12082323").to_return(status: 200, body: File.read('./spec/fixtures/bib.json'))
  end

  it "should authenticate when calling with :authenticate => true" do
    client = PlatformApiClient.new

    # Verify no access token:
    expect(client.instance_variable_get(:@access_token)).to be_nil

    # Call an endpoint with authentication:
    expect(client.get('bibs/sierra-nypl/b12082323', authenicate: true)).to be_a(Object)

    # Verify access_token retrieved:
    expect(client.instance_variable_get(:@access_token)).to be_a(String)
    expect(client.instance_variable_get(:@access_token)).to eq('fake-access-token')
  end
end
