# frozen_string_literal: true

require_relative '../base_crawler'
require 'minitest/unit'
require 'minitest/autorun'

class TestBaseCrawler < MiniTest::Unit::TestCase
  def setup
    @base_crawler = ::BaseCrawler.new
  end

  def test_have_user_agent_interface
    assert_respond_to(@base_crawler, :user_agent)
  end

  def test_have_base_uri_interface
    assert_respond_to(@base_crawler, :base_uri)
  end
end
