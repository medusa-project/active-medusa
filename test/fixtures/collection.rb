class Collection < ActiveMedusa::Container

  entity_class_uri 'http://example.org/Collection'

  has_many :items

  rdf_property :key,
               xs_type: :string,
               predicate: 'http://example.org/collectionKey',
               solr_field: 'key_s'
  rdf_property :published,
               xs_type: :boolean,
               predicate: 'http://example.org/isPublished',
               solr_field: 'published_b'

  validates :key, length: { minimum: 2, maximum: 20 }

end
