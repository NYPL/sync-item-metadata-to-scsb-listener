require 'aws-sdk-kms'
require 'base64'

class KmsClient
  def initialize
    @kms = Aws::KMS::Client.new(region: 'us-east-1')
  end 

  def decrypt(cipher)
    # Assume value is base64 encoded:
    decoded = Base64.strict_decode64 cipher
    decrypted = @kms.decrypt ciphertext_blob: decoded
    decrypted[:plaintext]
  end
end
