require_relative 'test_helper'

class QueryingTest < Minitest::Test

  def setup
    @http = HTTPClient.new
    @config = ActiveMedusa::Configuration.instance
    @seeder = Seeder.new(@config)
    @seeder.teardown
    @seeder.seed
    sleep 2 # wait for changes to propagate to solr
    ActiveMedusa::Solr.client.commit
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
    uri = @config.fedora_url + '/item1'
    assert_instance_of Item, Item.find(uri)
    assert_raises ActiveMedusa::RepositoryError do
      assert_nil Item.find_by_uri(uri + 'adfasfd')
    end
    assert_raises SocketError do
      assert_nil Item.find_by_uri('http://nonexistent')
    end
  end

  def test_find_by_id
    uri = @config.fedora_url + '/item1'
    assert_instance_of Item, Item.find_by_id(uri)
    assert_raises ActiveMedusa::RepositoryError do
      assert_nil Item.find_by_uri(uri + 'adfasfd')
    end
  end

  def test_find_by_property
    assert_instance_of Item, Item.find_by_full_text('lorem ipsum')
    assert_nil Item.find_by_full_text('nonexistent full text')
  end

  def test_find_by_uri
    uri = @config.fedora_url + '/item1'
    assert_instance_of Item, Item.find_by_uri(uri)
    assert_raises ActiveMedusa::RepositoryError do
      assert_nil Item.find_by_uri(uri + 'adfasfd')
    end
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
