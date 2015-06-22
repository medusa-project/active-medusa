module ActiveMedusa

  ##
  # ActiveMedusa configuration class.
  #
  class Configuration

    @@instance = nil

    attr_accessor :fedora_url
    attr_accessor :fedora_indexing_transformation
    attr_accessor :logger
    attr_accessor :class_predicate # must be indexed as :solr_class_field
    attr_accessor :solr_core
    attr_accessor :solr_class_field # must originate from :class_predicate
    attr_accessor :solr_uri_field
    attr_accessor :solr_more_like_this_endpoint
    attr_accessor :solr_uuid_field
    attr_accessor :solr_default_search_field
    attr_accessor :solr_facet_fields
    attr_accessor :solr_url

    def self.instance
      @@instance
    end

    def initialize
      self.fedora_indexing_transformation = 'default'
      self.solr_uri_field = :id
      self.solr_more_like_this_endpoint = '/mlt'
      yield self
      @@instance = self
    end

  end

end
