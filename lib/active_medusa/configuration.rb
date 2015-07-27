module ActiveMedusa

  ##
  # Singleton ActiveMedusa configuration class. See the readme for an example
  # of correct initialization.
  #
  class Configuration

    @@instance = nil

    ##
    # @!attribute fedora_url
    #   @return [String] Base URL of the Fedora server, typically ending in
    #   `/rest`.
    #
    attr_accessor :fedora_url

    ##
    # @!attribute logger
    #   @return [String] The logger to use. In a Rails app, this will probably
    #   be `Rails.logger`.
    #
    attr_accessor :logger

    ##
    # @!attribute class_predicate
    #   @return [String] Must originate from `:solr_class_field`.
    #
    attr_accessor :class_predicate

    ##
    # @!attribute solr_core
    #   @return [String] The name of the Solr core to use.
    #
    attr_accessor :solr_core

    ##
    # @!attribute solr_class_field
    #   @return [String] Must originate from `:class_predicate`.
    #
    attr_accessor :solr_class_field

    ##
    # @!attribute solr_uri_field
    #   @return [String] Name of the Solr field that stores the repository
    #   URL/URI.
    #
    attr_accessor :solr_uri_field

    ##
    # @!attribute class_predicate
    #   @return [String] Path of the "MoreLikeThis" endpoint. Defaults to
    #   `/mlt`.
    #
    attr_accessor :solr_more_like_this_endpoint

    attr_accessor :solr_uuid_field

    attr_accessor :solr_default_search_field

    ##
    # @!attribute solr_facet_fields
    #   @return [Array] Array of facetable fields. Can be overridden by
    #   `ActiveMedusa::Relation.facetable_fields`.
    #
    attr_accessor :solr_default_facetable_fields

    ##
    # @!attribute solr_url
    #   @return [String] Base URL of the Solr server.
    #
    attr_accessor :solr_url

    ##
    # @return [ActiveMedusa::Configuration] The shared `Configuration` instance.
    #
    def self.instance
      @@instance
    end

    def initialize
      self.solr_uri_field = :id
      self.solr_more_like_this_endpoint = '/mlt'
      yield self
      @@instance = self
    end

  end

end
