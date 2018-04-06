$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'open-uri'
require 'nokogiri'
require 'robotex'
require 'concerns/aws_config'
require 'concerns/standard_class_methods'

class BaseCralwer
  include StandardClassMethods
  attr_reader :current_page_number

  def user_agent
    'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36'
  end

  def base_uri
    'https://shuuumatu-worker.jp'
  end
end
