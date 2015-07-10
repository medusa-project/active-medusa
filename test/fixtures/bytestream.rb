class Bytestream < ActiveMedusa::Binary

  entity_class_uri 'http://example.org/Bytestream'

  belongs_to :item, rdf_predicate: 'http://example.org/isOwnedBy',
             solr_field: 'item'

end
