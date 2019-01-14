require 'aws-sdk-kms'
require 'base64'

class KmsClient
  @@kms = nil

  def initialize
    @kms = self.class.aws_kms_client
  end 

  def decrypt(cipher)
    # Assume value is base64 encoded:
    decoded = Base64.strict_decode64 cipher
    decrypted = @kms.decrypt ciphertext_blob: decoded
    decrypted[:plaintext]
  end

  def self.aws_kms_client
    @@kms = Aws::KMS::Client.new(region: 'us-east-1', stub_responses: ENV['APP_ENV'] == 'test') if @@kms.nil?
    @@kms
  end
end
