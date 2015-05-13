module ActiveMedusa

  ##
  # ActiveMedusa configuration class.
  #
  class Configuration

    @@instance

    attr_accessor :fedora_url
    attr_accessor :fedora_indexing_transformation
    attr_accessor :logger
    attr_accessor :namespace_prefix
    attr_accessor :namespace_uri
    attr_accessor :solr_core
    attr_accessor :solr_class_field
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
