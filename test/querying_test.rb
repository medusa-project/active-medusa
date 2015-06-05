require_relative 'test_helper'

class QueryingTest < Minitest::Test

  def setup
    @http = HTTPClient.new
    @config = ActiveMedusa::Configuration.instance
    @seeder = Seeder.new(@config)
    @seeder.teardown
    @seeder.seed
    sleep 2 # wait for changes to propagate to solr
    @http.get("#{@config.solr_url}/#{@config.solr_core}/update?commit=true")
    sleep 2 # wait for solr to commit
  end

  def teardown
    @seeder.teardown
  end

  def test_all
    all = Item.all
    assert_instance_of ActiveMedusa::Relation, all
    assert_equal 3, all.length
  end

  def test_find
    # get a valid UUID
    uuid = nil
    response = @http.get(@config.fedora_url + '/item1', nil,
                         { 'Accept' => 'application/n-triples' })
    graph = RDF::Graph.new
    graph.from_ntriples(response.body)
    graph.each_statement do |st|
      if st.predicate.to_s == 'http://fedora.info/definitions/v4/repository#uuid'
        uuid = st.object.to_s
        break
      end
    end
    assert_instance_of Item, Item.find(uuid)
    assert_raises RuntimeError do
      assert_nil Item.find('nonexistent uuid')
    end
  end

  def test_find_by_uri
    uri = @config.fedora_url + '/item1'
    assert_instance_of Item, Item.find_by_uri(uri)
    assert_nil Item.find_by_uri('http://nonexistent')
  end

  def test_find_by_uuid
    # get a valid UUID
    uuid = nil
    response = @http.get(@config.fedora_url + '/item1', nil,
                         { 'Accept' => 'application/n-triples' })
    graph = RDF::Graph.new
    graph.from_ntriples(response.body)
    graph.each_statement do |st|
      if st.predicate.to_s == 'http://fedora.info/definitions/v4/repository#uuid'
        uuid = st.object.to_s
        break
      end
    end
    assert_instance_of Item, Item.find_by_uuid(uuid)
    assert_nil Item.find_by_uuid('nonexistent uuid')
  end

  def test_find_by_rdf_property
    assert_instance_of Item, Item.find_by_full_text('lorem ipsum')
    assert_nil Item.find_by_full_text('nonexistent full text')
  end

  def test_method_forwarding
    assert_equal 3, Item.count
    assert_instance_of Item, Item.first
    assert_instance_of ActiveMedusa::Relation, Item.limit(1)
    assert_instance_of ActiveMedusa::Relation, Item.order(:title_s)
    assert_instance_of ActiveMedusa::Relation, Item.start(0)
    assert_instance_of ActiveMedusa::Relation, Item.where(title_s: 'dogs')
  end

  def test_none
    assert_instance_of ActiveMedusa::Relation, Item.none
  end

end
