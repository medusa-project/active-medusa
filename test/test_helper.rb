$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'active_medusa'
require 'minitest/autorun'
require 'minitest/reporters'

MiniTest::Reporters.use!

ActiveMedusa::Configuration.new do |config|
  config.fedora_url = 'http://localhost:8080/fedora/rest'
  config.fedora_indexing_transformation = 'activemedusa'
  config.class_predicate = 'http://example.org/hasClass'
  config.solr_url = 'http://localhost:8983/solr'
  config.solr_core = 'activemedusa'
  config.solr_class_field = :class_s
  config.solr_uuid_field = :uuid_s
  config.solr_default_search_field = :searchall_txt
  config.solr_facet_fields = [
      :collection_facet, :contributor_facet, :coverage_facet, :creator_facet,
      :date_facet, :format_facet, :language_facet, :publisher_facet,
      :source_facet, :subject_facet, :type_facet
  ]
end
