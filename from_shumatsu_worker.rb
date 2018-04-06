require './base_crawler'
require 'pry-byebug'

class FromShumatsuWorker < BaseCralwer
  def call
    robotex = ::Robotex.new
    return unless robotex.allowed?(base_uri)
    @s3 = Aws::S3::Resource.new(
      region: 'ap-northeast-1',
      retry_limit: 2,
      http_open_timeout: 5
    )

    doc = access_site('/list')
    last_page_number(doc)

    1.upto(@current_max_page_number) do |i|
      doc = access_site("/list/page/#{i}")
      items = doc.xpath("//div[@class='m-worklist__caption']/a")
      items.each do |item|
        detail_page = access_site("/" + item['href'].match(/\d+/)[0])
        @s3.put(body: detail_page.document)
      end
    end
  end

  def last_page_number(doc)
    pagenates = doc.xpath("//div[@class='yutopro_pagenavi']/a")

    loop do
      begin
        max_page_number = pagenates.map do |page|
          page['href'] =~ /page=(\d+)\z/
        end.compact.max
        access_site("page/#{current_max_page_number}")
        @current_max_page_number = pagenates.map do |page|
          page['href'] =~ /page=(\d+)\z/
        end.compact.max
        break if max_page_number == current_max_page_number
      rescue StandardError
        @current_max_page_number = 1 if max_page_number.nil?
        break
      end
    end
  end

  def access_site(path)
    binding.pry
    html = open(base_uri + path.to_s,
                'User-Agent' => user_agent) do |f|
      @charset = f.charset
      f.read
    end
    Nokogiri::HTML.parse(html, nil, @charset)
  end
end

FromShumatsuWorker.call
