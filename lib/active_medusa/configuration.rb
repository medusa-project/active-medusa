module ActiveMedusa

  ##
  # Singleton configuration class. See the readme for an example of correct
  # initialization.
  #
  class Configuration

    @@instance = nil

    ##
    # @!attribute fedora_url
    #   @return [String] Base URL of the Fedora REST API, typically ending in
    #     `/rest`.
    #
    attr_accessor :fedora_url

    ##
    # @!attribute logger
    #   @return [String] The logger to use. In a Rails app, this will probably
    #     be `Rails.logger`. If not set, an instance of Logger will log to
    #     stdout.
    #
    attr_accessor :logger

    ##
    # @!attribute class_predicate
    #   @return [String] RDF predicate to use to store entity type.
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
    # @!attribute solr_id_field
    #   @return [String] Name of the Solr field that stores the repository
    #     node ID.
    #
    attr_accessor :solr_id_field

    # @!attribute solr_more_like_this_endpoint
    #   @return [String] Path of the "MoreLikeThis" endpoint. Defaults to
    #     `/mlt`. (See https://wiki.apache.org/solr/MoreLikeThis for more
    #     information.)
    #
    attr_accessor :solr_more_like_this_endpoint

    # @!attribute solr_parent_uri_field
    #   @return [String] Name of the Solr field that stores the node's parent
    #     URI.
    #
    attr_accessor :solr_parent_uri_field

    # @!attribute solr_default_search_field
    #   @return [String] Name of the Solr field to search on by default.
    #
    attr_accessor :solr_default_search_field

    ##
    # @!attribute solr_default_facetable_fields
    #   @return [Array] Array of facetable fields. Can be overridden by
    #     `ActiveMedusa::Relation.facetable_fields`.
    #
    attr_accessor :solr_default_facetable_fields

    ##
    # @!attribute solr_url
    #   @return [String] Base URL of the Solr server, excluding the path to the
    #     core.
    #
    attr_accessor :solr_url

    ##
    # @return [ActiveMedusa::Configuration] The shared `Configuration` instance.
    #
    def self.instance
      @@instance
    end

    def initialize
      self.logger = Logger.new(STDOUT)
      self.solr_more_like_this_endpoint = '/mlt'
      yield self
      @@instance = self
    end

  end

end
