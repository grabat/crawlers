# frozen_string_literal: true

require_relative './base_crawler'
require 'pry-byebug'
require 'benchmark'

# shuuumatu-worker.jp crawler
class FromShumatsuWorker < BaseCrawler
  def initialize
    @threads = []
    @current_max_page_number = 1
    robotex = ::Robotex.new
    return unless robotex.allowed?(base_uri)
    @s3 = Aws::S3::Resource.new(
      region: 'ap-northeast-1',
      retry_limit: 2,
      http_open_timeout: 5
    )
    @bucket = @s3.bucket('grabat-crawler')
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
    html = NetHTTPWrapper.run(url_str: base_uri + path.to_s)
    Nokogiri::HTML.parse(html.body, nil, @charset)
  end

  def crawl
    1.upto(@current_max_page_number) do |i|
      @threads << Thread.new(i) do |index|
        doc = access_site("/list/page/#{index}")
        items = doc.xpath("//div[@class='m-worklist__caption']/a")
        save(items)
      end
    end

    @threads.each(&:join)
  end

  def save(items)
    items.each do |item|
      id = item['href'].match(/\d+/)[0]
      detail_page = access_site('/' + id)
      upload_to_s3(detail_page, id)
    end
  end

  def upload_to_s3(detail_page, id)
    file = @bucket.object("#{Time.now.strftime('%Y%m%d')}_#{id}.html")
    file.put(body: detail_page.document.to_s)
  end

  # Net::HTTP wrapper class
  class NetHTTPWrapper
    attr_reader :response
    def initialize(args = {})
      @url_str = args[:url_str]
      set_values(url: @url_str, limit: args[:limit] || 10)
    end

    class << self
      def run(**args)
        new(args).run
      end
    end

    def run
      @response = @https.start do |http|
        http.request(@req)
      end
      case @response.header.code.to_i
      when 200..299
        @response
      when 301
        set_values(url: @response['location'], limit: @limit - 1)
        run
      else
        @response
      end
    end

    def res
      case @response.header.code.to_i
      when 200..299
        @response
      when 301
        run(@response['location'], @limit - 1)
      else
        @response
      end
    end

    def net_http(host, port)
      Net::HTTP.new(host, port).tap do |https|
        https.use_ssl = true
        https.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end

    def set_values(args)
      @url_str = args[:url] || @url_str
      @limit = args[:limit] || 10
      @url = URI.parse(@url_str)
      @req = Net::HTTP::Get.new(@url.path)
      @https = net_http(@url.host, @url.port)
    end
  end
end

fsw = FromShumatsuWorker.new
fsw.run
