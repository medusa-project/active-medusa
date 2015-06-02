class Item < ActiveMedusa::Container

  entity_class_uri 'http://example.org/Item'

  belongs_to :collection, predicate: 'http://example.org/isMemberOf',
             solr_field: :collection_s
  belongs_to :item, predicate: 'http://example.org/isChildOf',
             solr_field: :parent_uri_s, name: :parent_item
  has_many :bytestreams, predicate: 'http://example.org/hasBytestream'
  has_many :items

  rdf_property :full_text,
               xs_type: :string,
               predicate: 'http://example.org/fullText',
               solr_field: 'full_text_txt'
  rdf_property :page_index,
               xs_type: :int,
               predicate: 'http://example.org/pageIndex',
               solr_field: 'page_index_i'
  rdf_property :published,
               xs_type: :boolean,
               predicate: 'http://example.org/isPublished',
               solr_field: 'published_b'
end
