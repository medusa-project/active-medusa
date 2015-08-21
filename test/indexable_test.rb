require_relative 'test_helper'

class IndexableTest < Minitest::Test

  def setup
    @http = HTTPClient.new
    @config = ActiveMedusa::Configuration.instance
    @seeder = Seeder.new(@config)
    @seeder.teardown
    @seeder.seed
    @solr = ActiveMedusa::Solr.client
    sleep 2 # wait for changes to propagate to solr
    @http.get("#{@config.solr_url}/#{@config.solr_core}/update?commit=true")
    sleep 2 # wait for solr to commit
  end

  def teardown
    # delete everything from Solr
    url = @config.solr_url.chomp('/') + '/' + @config.solr_core
    @http = HTTPClient.new
    @http.get(url + '/update?stream.body=<delete><query>*:*</query></delete>')
    @solr.commit
  end

  def test_delete_from_solr
    # get a random item
    item = Item.all.first
    # delete it
    item.delete
    sleep 2
    @solr.commit
    sleep 2
    # check that it no longer exists in solr
    response = @solr.get(
        'select', params: { q: "#{@config.solr_id_field}:\"#{item.id}\"" })
    assert_equal 0, response['response']['docs'].length
  end

  def test_reindex_in_solr
    # reindex_in_solr will have already been invoked during seeding
    response = @solr.get(
        'select', params: { q: '*:*' })
    assert response['response']['docs'].length > 0
  end

  def test_solr_document
    item = Item.all.first
    doc = item.solr_document
    # test presence of fields required by activemedusa
    assert_equal item.id, doc[@config.solr_id_field]
    assert_equal item.class.entity_class_uri, doc[@config.solr_class_field]
    assert_equal item.rdf_graph.any_object('http://fedora.info/definitions/v4/repository#hasParent').to_s,
                 doc[@config.solr_parent_uri_field]

    # test presence of fields corresponding to property statements
    item.class.properties.select{ |p| p.class == item.class }.each do |prop|
      assert_equal item.send(prop.name), doc[prop.solr_field]
    end

    # test presence of fields corresponding to associations
    item.class.associations.
        select{ |a| a.class == item.class and
        a.type == Association::Type::BELONGS_TO }.each do |assoc|
      obj = item.send(assoc.name)
      assert_equal obj.repository_url, doc[assoc.solr_field] if obj.kind_of?(Base)
    end

  end

end
