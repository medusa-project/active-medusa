require 'active_medusa/base'

module ActiveMedusa

  ##
  # Abstract class from which all ActiveMedusa container entities should
  # inherit.
  #
  class Container < Base
    include Querying

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
      transactional_url(self.repository_url).chomp('/')
    end

    protected

    def fetch_current_graph
      graph = RDF::Graph.new
      url = transactional_url(self.repository_url)
      if url
        response = Fedora.client.get(
            url, nil, { 'Accept' => 'application/n-triples' })
        graph.from_ntriples(response.body)
      end
      graph
    end

    ##
    # Creates a new node.
    #
    # @raise [RuntimeError]
    #
    def save_new
      run_callbacks :create do
        url = transactional_url(self.container_url)
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