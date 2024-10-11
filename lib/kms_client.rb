require 'aws-sdk-kms'
require 'base64'

class KmsClient
  @@kms = nil

  def initialize
    @kms = self.class.aws_kms_client
  end

  def decrypt(cipher)
    # Assume value is base64 encoded:
    decoded = Base64.decode64 cipher
    decrypted = @kms.decrypt ciphertext_blob: decoded
    decrypted[:plaintext]
  end

  def self.aws_kms_client
    if ENV['LOCAL']
      @@kms = Aws::KMS::Client.new(
        region: 'us-east-1',
        stub_responses: ENV['APP_ENV'] == 'test',
        access_key_id:  ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
      ) if @@kms.nil?
    else
      @@kms = Aws::KMS::Client.new(region: 'us-east-1', stub_responses: ENV['APP_ENV'] == 'test') if @@kms.nil?
    end
    @@kms
  end
end
