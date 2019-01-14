require 'spec_helper'
require 'webmock/rspec'
require 'aws-sdk-kms'

describe KmsClient do
  before(:each) do
    KmsClient.aws_kms_client.stub_responses(:decrypt, -> (context) {
      # "Decrypt" by subbing "encrypted" with "decrypted" in string:
      { plaintext: context.params[:ciphertext_blob].gsub('encrypted', 'decrypted') }
    })
  end

  it "should use class scoped aws-sdk kms client" do
    expect(KmsClient.aws_kms_client.decrypt(ciphertext_blob: 'encrypted-garbage')).to be_a(Seahorse::Client::Response)
    expect(KmsClient.aws_kms_client.decrypt(ciphertext_blob: 'encrypted-garbage')[:plaintext]).to eq('decrypted-garbage')
  end

  it "should decrypt base64 encoded strings" do
    val = Base64.strict_encode64 'something-encrypted'
    expect(KmsClient.new.decrypt(val)).to eq('something-decrypted')
  end
end
