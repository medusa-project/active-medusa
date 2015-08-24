require_relative 'test_helper'

class BaseTest < Minitest::Test

  # Any entities created in the tests should use one of these slugs, to ensure
  # that they get torn down.
  SLUGS = %w(node1 node2 node3 node4 node5 node6 node7 node8 node9 node10)

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

  # create

  def test_create
    item = Item.create(parent_url: @config.fedora_url, full_text: 'cats',
                       requested_slug: SLUGS[0])
    assert item.persisted?
    item = Item.create!(parent_url: @config.fedora_url, full_text: 'cats',
                       requested_slug: SLUGS[1])
    assert item.persisted?
  end

  def test_create_callbacks
    item = Item.create(parent_url: @config.fedora_url, full_text: 'cats',
                       requested_slug: SLUGS[0])
    assert item.instance_variable_get('@before_create_called')
    assert item.instance_variable_get('@after_create_called')
  end

  # entity_class_uri

  def test_entity_class_uri
    assert_equal 'http://example.org/Item', Item.entity_class_uri
  end

  # load

  def test_load_with_existing_node
    item = Item.create!(parent_url: @config.fedora_url,
                        requested_slug: SLUGS[0],
                        full_text: 'cats')
    actual = ActiveMedusa::Base.load(item.repository_url)
    assert_kind_of Item, actual
    assert_equal 'cats', actual.full_text
  end

  def test_load_with_nonexistent_node
    assert_raises ActiveMedusa::RepositoryError do
      ActiveMedusa::Base.load(@config.fedora_url + '/blablabla')
    end
  end

  # property

  def test_property_creates_accessor
    item = Item.new
    item.full_text = 'cats'
    assert_equal 'cats', item.full_text
  end

  def test_property_requires_certain_options
    assert_raises RuntimeError do
      Item::property :something, invalid: 'bla', invalid2: 'bla'
    end
  end

  # initialize

  def test_initialize_requires_a_hash
    assert_raises ArgumentError do
      Item.new('cats')
    end
  end

  def test_initialize_should_ignore_id
    model = Item.new(id: 'cats')
    assert_nil model.id
  end

  def test_initialize_sets_reasonable_defaults
    item = Item.new
    assert !item.instance_variable_get('@destroyed')
    assert !item.instance_variable_get('@loaded')
    assert !item.instance_variable_get('@persisted')
  end

  def test_initialize_should_accept_properties
    text = 'test test test'
    item = Item.new(full_text: text)
    assert_equal text, item.full_text
  end

  # created_at

  def test_created_at
    item = Item.new(parent_url: @config.fedora_url, requested_slug: SLUGS[0])
    assert_nil item.created_at
    item.save!
    item.rdf_graph.each_statement do |st|
      if st.predicate.to_s ==
          'http://fedora.info/definitions/v4/repository#created'
        assert_equal Time.parse(st.object.to_s), item.created_at
        break
      end
    end
  end

  # destroy

  def test_destroy_should_destroy
    item = Item.create!(parent_url: @config.fedora_url,
                        requested_slug: SLUGS[0])
    item.destroy
    assert item.destroyed?
    assert item.frozen?
    assert_raises HTTPClient::BadResponseError do
      assert_equal 410, @http.get("#{@config.fedora_url}/#{SLUGS[0]}").status
      assert_equal 405, @http.get("#{@config.fedora_url}/#{SLUGS[0]}/fcr:tombstone").status
    end
  end

  def test_destroy_also_tombstone_parameter_should_work
    item = Item.create!(parent_url: @config.fedora_url,
                        requested_slug: SLUGS[0])
    item.destroy(also_tombstone: true)
    assert item.destroyed?
    assert_raises HTTPClient::BadResponseError do
      assert_equal 410, @http.get("#{@config.fedora_url}/#{SLUGS[0]}").status
      assert_equal 405, @http.get("#{@config.fedora_url}/#{SLUGS[0]}/fcr:tombstone").status
    end
  end

  def test_destroy_callbacks
    item = Item.create(parent_url: @config.fedora_url,
                       requested_slug: SLUGS[0])
    item.destroy
    assert item.instance_variable_get('@before_destroy_called')
    # TODO: test after_destroy
  end

  # destroyed?

  def test_destroyed
    item = Item.create(parent_url: @config.fedora_url,
                       requested_slug: SLUGS[0])
    assert !item.destroyed?
    item.delete
    assert item.destroyed?
  end

  # persisted?

  def test_persisted
    item = Item.new(parent_url: @config.fedora_url, requested_slug: SLUGS[0])
    assert !item.persisted?
    item.save!
    assert item.persisted?
  end

  # reload!

  def test_reload_should_refresh_the_instance
    # create a new item
    item = Item.create!(parent_url: @config.fedora_url,
                        requested_slug: SLUGS[0])
    # update the RDF of the corresponding container
    response = @http.get(item.repository_url, nil,
                         { 'Accept' => 'application/n-triples' })
    title = 'awesome new title'
    graph = RDF::Graph.new
    graph.from_ntriples(response.body)
    graph << [RDF::URI(), RDF::URI('http://purl.org/dc/terms/title'), title]
    @http.put(item.repository_url, graph.to_ttl,
              { 'Content-Type' => 'text/turtle' })
    # reload the item
    item.reload!
    found = false
    item.rdf_graph.each_statement do |st|
      if st.predicate.to_s == 'http://purl.org/dc/terms/title'
        assert_equal title, st.object.to_s
        found = true
        break
      end
    end
    flunk unless found
  end

  # requested_slug

  def test_requested_slug_works_with_new_slug
    expected_url = "#{@config.fedora_url}/#{SLUGS[5]}"
    assert_raises HTTPClient::BadResponseError do
      assert_equal 404, @http.get(expected_url).status
    end
    Item.create!(parent_url: @config.fedora_url, requested_slug: SLUGS[5])
    assert_equal 200, @http.get(expected_url).status
  end

  # save

  def test_save_on_a_new_instance_should_create_it
    expected_url = "#{@config.fedora_url}/#{SLUGS[0]}"
    assert_raises HTTPClient::BadResponseError do
      assert_equal 404, @http.get(expected_url).status
    end
    item = Item.new(parent_url: @config.fedora_url, requested_slug: SLUGS[0])
    item.save
    assert_equal 200, @http.get(expected_url).status
  end

  def test_save_on_an_existing_instance_should_update_it
    item = Item.create!(parent_url: @config.fedora_url,
                        requested_slug: SLUGS[0])
    title = 'awesome new title'
    item.rdf_graph << [RDF::URI(), RDF::URI('http://purl.org/dc/terms/title'),
                       title]
    item.save!
    # get the RDF of the corresponding container and make sure it contains the
    # title we just added
    response = @http.get(item.repository_url, nil,
                         { 'Accept' => 'application/n-triples' })
    graph = RDF::Graph.new
    graph.from_ntriples(response.body)
    found = false
    graph.each_statement do |st|
      if st.predicate.to_s == 'http://purl.org/dc/terms/title'
        assert_equal title, st.object.to_s
        found = true
        break
      end
    end
    flunk unless found
  end

  def test_save_callbacks
    item = Item.new(parent_url: @config.fedora_url, full_text: 'cats')
    item.save!
    assert item.instance_variable_get('@before_save_called')
    assert item.instance_variable_get('@after_save_called')
  end

  def test_save_consecutively
    item = Item.new(parent_url: @config.fedora_url, full_text: 'cats')
    3.times { item.save! }
  end

  ##
  # When a child node N2 is added to a node N1, N1's lastModified triple gets
  # updated. This tests whether a stale instance of N1 will still save.
  #
  def test_stale_save
    collection = Collection.create!(parent_url: @config.fedora_url,
                                    requested_slug: SLUGS[0],
                                    key: 'cats')

    item = Item.create!(parent_url: collection.repository_url,
                        requested_slug: SLUGS[1])
    item.collection = collection
    item.save!

    collection.key = 'dogs'
    collection.save! # absence of an error is a pass
  end

  # update

  def test_update_should_update_the_instance
    # create an item
    item = Item.create!(parent_url: @config.fedora_url, full_text: 'cats')
    # update it
    item.update(full_text: 'dogs')
    # get its current RDF from the repository
    response = @http.get(item.repository_url, nil,
                         { 'Accept' => 'application/n-triples' })
    graph = RDF::Graph.new
    graph.from_ntriples(response.body)
    # check that it was updated
    found = false
    graph.each_statement do |st|
      if st.predicate.to_s == 'http://example.org/fullText'
        assert_equal 'dogs', st.object.to_s
        found = true
      end
    end
    flunk unless found
  end

  def test_update_callbacks
    item = Item.create!(parent_url: @config.fedora_url, full_text: 'cats')
    item.update(full_text: 'dogs')
    assert item.instance_variable_get('@before_update_called')
    assert item.instance_variable_get('@after_update_called')
  end

  # updated_at

  def test_updated_at
    item = Item.new(parent_url: @config.fedora_url, requested_slug: SLUGS[0])
    assert_nil item.updated_at
    item.save!
    item.rdf_graph.each_statement do |st|
      if st.predicate.to_s ==
          'http://fedora.info/definitions/v4/repository#lastModified'
        assert_equal Time.parse(st.object.to_s), item.updated_at
        break
      end
    end
  end

end
