require_relative 'test_helper'

class RelationshipsTest < Minitest::Test

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

  # associations

  def test_associations
    assert_equal 6, Item.associations.length
  end

  # belongs_to

  def test_belongs_to_requires_certain_options
    assert_raises RuntimeError do
      Item::belongs_to :something, invalid: 'bla', invalid2: 'bla'
    end
  end

  def test_cannot_belong_to_parent
    assert_raises RuntimeError do
      Item::belongs_to :parent, predicate: 'bla', solr_field: 'bla'
    end
  end

  def test_belongs_to_creates_accessors
    bs = Bytestream.new
    item = Item.new
    bs.item = item
    assert_equal item, bs.item
  end

  def test_belongs_to_works
    item = Item.create!(parent_url: @config.fedora_url, full_text: 'cats')
    bs = Bytestream.create!(parent_url: item.repository_url,
                            requested_slug: SLUGS.first,
                            upload_pathname: __FILE__)
    bs.item = item
    bs.save!

    # make sure the relationship appears in the graph
    response = @http.get(bs.repository_metadata_url, nil,
                         { 'Accept' => 'application/n-triples' })
    graph = RDF::Graph.new
    graph.from_ntriples(response.body)
    association = Bytestream.associations.
        select{ |a| a.source_class == bs.class and
        a.target_class == item.class and
        a.type == ActiveMedusa::Association::Type::BELONGS_TO }.first
    found = false
    graph.each_statement do |st|
      if st.predicate == association.rdf_predicate
        found = true
      end
    end
    assert found
  end

  # children

  def test_children
    # item without children
    item = Item.create!(parent_url: @config.fedora_url,
                        requested_slug: SLUGS[4])
    assert_equal 0, item.children.length
    item.reload!
    assert_equal 0, item.children.length

    # item with children
    parent = Item.create!(parent_url: @config.fedora_url,
                          requested_slug: SLUGS[0])
    children = []
    children << Item.create!(parent_url: parent.repository_url,
                             requested_slug: SLUGS[1])
    children << Item.create!(parent_url: parent.repository_url,
                             requested_slug: SLUGS[2])
    children << Item.create!(parent_url: parent.repository_url,
                             requested_slug: SLUGS[1])
    Item.create!(parent_url: children.first.repository_url,
                             requested_slug: SLUGS[3])
    parent.reload!
    assert_equal 3, parent.children.length
  end

  # parent

  def test_parent
    parent = Item.create!(parent_url: @config.fedora_url,
                          requested_slug: SLUGS[0])
    child = Item.create!(parent_url: parent.repository_url,
                         requested_slug: SLUGS[1])
    parent.reload!
    child.reload!
    assert_equal parent.id, child.parent.id
  end

end
