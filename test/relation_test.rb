require_relative 'test_helper'

class RelationTest < Minitest::Test

  # Any entities created in the tests should use one of these slugs, to ensure
  # that they get torn down.
  SLUGS = %w(item1 item2 item3 item4 item5 item6 item7 item8 item9 item10)

  def setup
    @config = ActiveMedusa::Configuration.instance
    @http = HTTPClient.new
  end

  def teardown
    SLUGS.each do |slug|
      @http.delete("#{@config.fedora_url}/#{slug}") rescue nil
      @http.delete("#{@config.fedora_url}/#{slug}/fcr:tombstone") rescue nil
    end
  end

  # count

  def test_count
    items = Item.all
    assert_equal items.to_a.length, items.count
  end

  # solr_response

  ##
  # Tests that solr_response is populated after a request.
  #
  def test_solr_response
    items = Item.all
    assert_nil items.solr_response
    items.to_a
    assert_kind_of Hash, items.solr_response
  end

  # where

  def test_where_after_loaded
    # calling where() after load should mark the relation "not loaded" and
    # clear any results already gathered
    # TODO: write this
  end

end
