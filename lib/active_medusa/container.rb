require 'active_medusa/base'

module ActiveMedusa

  ##
  # Abstract class from which all ActiveMedusa container entities should
  # inherit.
  #
  class Container < Base
    include Querying

    # @!attribute binaries_to_add
    #   @return [Set]
    attr_reader :binaries_to_add

    # @!attribute score
    #   @return [Float] Float populated by `ActiveMedusa::Relation`; not
    #           persisted.
    attr_accessor :score

    # @!attribute solr_representation
    #   @return [Hash] Hash of the instance's representation in Solr.
    attr_accessor :solr_representation

    ##
    # @param params [Hash]
    #
    def initialize(params = {})
      @binaries_to_add = Set.new
      @rdf_graph = new_rdf_graph
      super
    end

    ##
    # @return [ActiveMedusa::Relation]
    #
    def more_like_this
      ActiveMedusa::Relation.new(self).more_like_this
    end

    def repository_metadata_url
      self.repository_url ?
          transactional_url(self.repository_url).chomp('/') : nil
    end

    protected

    ##
    # Creates a new node.
    #
    # @raise [RuntimeError]
    #
    def save_new
      run_callbacks :create do
        populate_graph(self.rdf_graph)
        url = transactional_url(self.parent_url)
        body = self.rdf_graph.to_ttl
        headers = { 'Content-Type' => 'text/turtle' }
        headers['Slug'] = self.requested_slug if self.requested_slug.present?
        # TODO: prefixes http://blog.datagraph.org/2010/04/parsing-rdf-with-ruby
        begin
          response = Fedora.client.post(url, body, headers)
        rescue HTTPClient::BadResponseError => e
          raise "#{e.res.status}: #{e.res.body}"
        end
        self.repository_url = nontransactional_url(response.header['Location'].first)
        self.requested_slug = nil
        @persisted = true
        self.reload!
      end
    end

    private

    ##
    # @return [RDF::Graph]
    #
    def new_rdf_graph
      graph = RDF::Graph.new
      graph << RDF::Statement.new(
          RDF::URI(),
          RDF::URI('http://fedora.info/definitions/v4/indexing#hasIndexingTransformation'),
          Configuration.instance.fedora_indexing_transformation)
      graph << RDF::Statement.new(
          RDF::URI(),
          RDF::URI('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'),
          RDF::URI('http://fedora.info/definitions/v4/indexing#Indexable'))
      graph << RDF::Statement.new(
          RDF::URI(), RDF::URI(Configuration.instance.class_predicate),
          RDF::URI(self.class.entity_class_uri))
      graph
    end

  end

end
