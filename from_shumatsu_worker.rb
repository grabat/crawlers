require './base_crawler'
require 'pry-byebug'

class FromShumatsuWorker < BaseCralwer
  def call
    @current_max_page_number = 1
    robotex = ::Robotex.new
    return unless robotex.allowed?(base_uri)
    @s3 = Aws::S3::Resource.new(
      region: 'ap-northeast-1',
      retry_limit: 2,
      http_open_timeout: 5
    )
    @bucket = @s3.bucket('grabat-crawler')

    last_page_number

    1.upto(@current_max_page_number) do |i|
      doc = access_site("/list/page/#{i}")
      items = doc.xpath("//div[@class='m-worklist__caption']/a")
      items.each do |item|
        detail_page = access_site('/' + item['href'].match(/\d+/)[0])
        file = @bucket.object(item['href'].match(/\d+/)[0] + '.html')
        file.put(body: detail_page.document.to_s)
      end
    end
  end

  def last_page_number
    loop do
      begin
        doc = access_site("/list/page/#{@current_max_page_number}")
        pagenates = doc.xpath("//div[@class='yutopro_pagenavi']/a")
        current_max_page = pagenates.map do |page|
          page['href'] =~ /page\/(\d+)\z/
        end.compact.max || 1
        break if current_max_page == @current_max_page_number || @current_max_page_number == 1
        @current_max_page_number = current_max_page
      rescue StandardError
        break
      end
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
end

FromShumatsuWorker.call
