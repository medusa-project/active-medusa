class Collection < ActiveMedusa::Container

  entity_class_uri 'http://example.org/Collection'

  has_many :items

  property :key,
           type: :string,
           rdf_predicate: 'http://example.org/collectionKey',
           solr_field: 'key_s'
  property :published,
           type: :boolean,
           rdf_predicate: 'http://example.org/isPublished',
           solr_field: 'published_b'

  validates :key, length: { minimum: 2, maximum: 20 }

end
