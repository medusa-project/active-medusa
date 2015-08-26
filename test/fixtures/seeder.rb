require 'active_medusa/configuration'
require 'active_medusa/fedora'
require 'rdf'

class Seeder

  def initialize(config)
    @http = ActiveMedusa::Fedora
    @config = config
  end

  def seed
    # Seed data structure:
    #
    # item 1
    #   bytestream 1
    #   bytestream 2
    # collection 1
    #   item 2
    #     bytestream 3
    #     item 3
    #       bytestream 4
    #
    item_1 = Item.new(parent_url: @config.fedora_url, requested_slug: 'item1',
                      full_text: 'lorem ipsum')
    item_1.rdf_graph << RDF::Statement.new(
        RDF::URI(), RDF::URI('http://purl.org/dc/elements/1.1/title'), 'Item 1')
    item_1.save!

    bytestream_1 = Bytestream.new(parent_url: item_1.repository_url,
                                  upload_pathname: File.join(__dir__, 'stupid_signs.jpg'),
                                  requested_slug: 'bytestream1',
                                  item: item_1)
    bytestream_1.save!

    bytestream_2 = Bytestream.new(parent_url: item_1.repository_url,
                                  upload_pathname: File.join(__dir__, 'stupid_signs.jpg'),
                                  requested_slug: 'bytestream2',
                                  item: item_1)
    bytestream_2.save!

    collection_1 = Collection.new(parent_url: @config.fedora_url,
                                  requested_slug: 'collection1',
                                  key: 'collection1')
    collection_1.rdf_graph << RDF::Statement.new(
        RDF::URI(), RDF::URI('http://purl.org/dc/elements/1.1/title'), 'Collection 1')
    collection_1.save!

    item_2 = Item.new(parent_url: collection_1.repository_url,
                      requested_slug: 'item2', collection: collection_1)
    item_2.rdf_graph << RDF::Statement.new(
        RDF::URI(), RDF::URI('http://purl.org/dc/elements/1.1/title'), 'Item 2')
    item_2.save!

    bytestream_3 = Bytestream.new(parent_url: item_2.repository_url,
                                  external_resource_url: 'https://www.google.com/',
                                  requested_slug: 'bytestream3', item: item_2)
    bytestream_3.save!

    item_3 = Item.new(parent_url: item_2.repository_url,
                      requested_slug: 'item3', collection: collection_1)
    item_3.rdf_graph << RDF::Statement.new(
        RDF::URI(), RDF::URI('http://purl.org/dc/elements/1.1/title'), 'Item 3')
    item_3.save!

    bytestream_4 = Bytestream.new(parent_url: item_3.repository_url,
                                  external_resource_url: 'https://www.google.com/',
                                  requested_slug: 'bytestream4', item: item_3)
    bytestream_4.save!
  end

  def teardown
    f4_url = @config.fedora_url
    urls_to_delete = ['/collection1', '/item1', '/item1/bytestream1',
                      '/item1/bytestream2', '/item2', '/item2/bytestream3',
                      '/item2/item3', '/item2/item3/bytestream4']
    urls_to_delete.each do |url|
      @http.delete(f4_url + url) rescue nil
      @http.delete(f4_url + url + '/fcr:tombstone') rescue nil
    end
    
    url = @config.solr_url.chomp('/') + '/' + @config.solr_core
    @http.get(url + '/update?stream.body=<delete><query>*:*</query></delete>')
    @http.get(url + '/update?stream.body=<commit/>')
  end

end
