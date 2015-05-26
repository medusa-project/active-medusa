module ActiveMedusa

  ##
  # ActiveMedusa configuration class.
  #
  class Configuration

    @@instance = nil

    attr_accessor :entity_path
    attr_accessor :fedora_url
    attr_accessor :fedora_indexing_transformation
    attr_accessor :logger
    attr_accessor :class_predicate # must be indexed as :solr_class_field
    attr_accessor :solr_core
    attr_accessor :solr_class_field # must originate from :class_predicate
    attr_accessor :solr_id_field
    attr_accessor :solr_parent_id_field
    attr_accessor :solr_uuid_field
    attr_accessor :solr_default_search_field
    attr_accessor :solr_facet_fields
    attr_accessor :solr_url

    def self.instance
      @@instance
    end

    def initialize
      yield self
      @@instance = self
    end

  end

end
