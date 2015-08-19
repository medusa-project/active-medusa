$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'active_medusa'
require 'minitest/autorun'

autoload :Bytestream, './fixtures/bytestream'
autoload :Collection, './fixtures/collection'
autoload :Item, './fixtures/item'
autoload :Seeder, './fixtures/seeder'

ActiveMedusa::Configuration.new do |config|
  config.fedora_url = 'http://localhost:8080/fedora/rest'
  config.class_predicate = 'http://www.w3.org/2000/01/rdf-schema#Class'
  config.solr_url = 'http://localhost:8983/solr'
  config.solr_core = 'activemedusa'
  config.solr_more_like_this_endpoint = '/mlt'
  config.solr_class_field = :class_s
  config.solr_parent_uri_field = :parent_uri_s
  config.solr_uri_field = :id
  config.solr_uuid_field = :uuid_s
  config.solr_default_search_field = :searchall_txt
  config.solr_default_facetable_fields = [
      :collection_facet, :contributor_facet, :coverage_facet, :creator_facet,
      :date_facet, :format_facet, :language_facet, :publisher_facet,
      :source_facet, :subject_facet, :type_facet
  ]
end
