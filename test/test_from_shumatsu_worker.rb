# frozen_string_literal: true

require_relative '../from_shumatsu_worker'
require 'minitest/autorun'

class TestFromShumatsuWorker < Minitest::Test
  def setup
    @crawler = FromShumatsuWorker.new
  end

  def test_call
    crawl_mock = MiniTest::Mock.new
    crawl_mock.expect(:call, 'called!')
    @crawler.stub :crawl, crawl_mock do
      @crawler.run
      assert_equal crawl_mock.verify, true
    end
  end
end
