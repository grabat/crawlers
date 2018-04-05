require 'open-uri'
require 'nokogiri'
require 'concern/aws_config'

class FromShumatsuWorker
  include StandardClassMethods
  attr_reader :current_page_number, :base_uri
  @@user_agent = 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36'
  @@base_uri = 'https://shuuumatu-worker.jp'

  def call
    robotex = Robotex.new
    return unless robotex.allowed?(@@base_uri)
    @s3 = Aws::S3::Resource.new(
      region: 'ap-northeast-1' ,
      retry_limit: 2,
      http_open_timeout: 5
    )

    doc = access_site("/list")
    set_last_page_number(doc)

    @current_max_page_number.time do |i|
      doc = access_site("/list/page/#{i}")
      items = doc.at_xpath("div[@class='m-worklist__caption']/a")
      items.each do |item|
        detail_page = access_site(item['href'])
        @s3.put(body: detail.document)
      end
    end
  end

  def set_last_page_number(doc)
    pagenates = doc.xpath("//div[@class='yutopro_pagenavi']/a")

    loop do
      begin
        max_page_number = pagenates.map { |page| page['href'] =~ /page=(\d+)\z/ }.compact.max
        access_site("page/#{current_max_page_number}")
        @current_max_page_number = pagenates.map { |page| page['href'] =~ /page=(\d+)\z/ }.compact.max
        break if max_page_number == current_max_page_number
      rescue StandardError
        @current_max_page_number = 1 if max_page_number.nil?
        break
      end
    end
  end

  def access_site(path)
    html = open(@@base_uri + path.to_s,
                'User-Agent' => @@use_agent) do |f|
      @charset = f.charset
      f.read
    end
    Nokogiri::HTML.parse(html, nil, @charset)
  end
end
