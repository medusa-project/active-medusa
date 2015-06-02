class Bytestream < ActiveMedusa::Binary

  entity_class_uri 'http://example.org/Bytestream'

  belongs_to :item, predicate: 'http://example.org/isOwnedBy'

end
