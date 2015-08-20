require_relative 'test_helper'

class ContainerTest < Minitest::Test

  # Any entities created in the tests should use one of these slugs, to ensure
  # that they get torn down.
  SLUGS = 10.times.map{ |i| "con#{i}" }

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

  # initialize

  def test_rdf_graph_initialization
    item = Item.new
    found_count = 0
    item.rdf_graph.each_statement do |st|
      if st.predicate.to_s == @config.class_predicate and
          st.object.to_s == 'http://example.org/Item'
        found_count += 1
      elsif st.predicate.to_s == 'http://fedora.info/definitions/v4/indexing#hasIndexingTransformation' and
          st.object.to_s == @config.fedora_indexing_transformation
        found_count += 1
      elsif st.predicate.to_s == 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type' and
          st.object.to_s == 'http://fedora.info/definitions/v4/indexing#Indexable'
        found_count += 1
      end
    end
    flunk unless found_count == 3
  end

  # more_like_this

  def test_more_like_this # TODO: make this test more complete
    item = Item.new
    assert_kind_of ActiveMedusa::Relation, item.more_like_this
  end

  # repository_metadata_url

  def test_repository_metadata_url
    url = "http://example.org/#{SLUGS[0]}"
    item = Item.new(repository_url: url)
    assert_equal url, item.repository_metadata_url
  end

  # saving is tested in base_test

end
