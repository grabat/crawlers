require 'aws-sdk'

Aws.config.update(
  region: 'us-west-2',
  credentials: Aws::Credentials.new('akid', 'secret')
)

class S3Uploader
  attr_reader :upload_id
  def initialize
    client = Aws::S3::Client.new
  end
end

