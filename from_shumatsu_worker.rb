require './base_crawler'
require 'pry-byebug'

# shuuumatu-worker.jp crawler
class FromShumatsuWorker < BaseCralwer
  def initialize
    @current_max_page_number = 1
    robotex = ::Robotex.new
    return unless robotex.allowed?(base_uri)
    @s3 = Aws::S3::Resource.new(
      region: 'ap-northeast-1',
      retry_limit: 2,
      http_open_timeout: 5
    )
    @bucket = @s3.bucket('grabat-crawler')
    super
  end

  def run
    last_page_number
    crawl
  end

  private

  def last_page_number
    loop do
      doc = access_site("/list/page/#{@current_max_page_number}")
      pagenates = doc.xpath("//div[@class='yutopro_pagenavi']/a")
      current_max_page = pagenates.map do |page|
        page['href'] =~ %r{page\/(\d+)\z}
      end.compact.max || 1
      break if [@current_max_page_number, 1].include?(current_max_page)
      @current_max_page_number = current_max_page
    end
  end

  def access_site(path)
    html = open(base_uri + path.to_s,
                'User-Agent' => user_agent,
                ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE) do |f|
      @charset = f.charset
      f.read
    end
    Nokogiri::HTML.parse(html, nil, @charset)
  end

  def crawl
    1.upto(@current_max_page_number) do |i|
      doc = access_site("/list/page/#{i}")
      items = doc.xpath("//div[@class='m-worklist__caption']/a")
      save(items)
    end
  end

  def save(items)
    items.each do |item|
      detail_page = access_site('/' + item['href'].match(/\d+/)[0])
      upload_to_s3(detail_page)
    end
  end

  def upload_to_s3(detail_page)
    file = @bucket.object(Time.now.strftime('%Y%m%d') + item['href']
      .match(/\d+/)[0] + '.html')
    file.put(body: detail_page.document.to_s)
  end
end

FromShumatsuWorker.run
