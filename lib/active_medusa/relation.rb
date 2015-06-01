require 'active_medusa/facet'
require 'active_medusa/result_set'
require 'active_medusa/solr'
require 'active_medusa/transactions'
require 'httpclient'

module ActiveMedusa

  ##
  # Query builder class, conceptually similar to [ActiveRecord::Relation].
  #
  class Relation

    include Transactions

    # @!attribute solr_request
    #   @return [Hash]
    attr_reader :solr_request

    # @!attribute solr_response
    #   @return [Hash]
    attr_reader :solr_response

    attr_accessor :transaction_url

    ##
    # @param caller [ActiveMedusa::Base] The calling entity, or `nil` to
    # initialize an "empty query", i.e. one that will return no results.
    #
    def initialize(caller = nil)
      @calling_class = caller.kind_of?(Class) ? caller : caller.class
      @facet = false
      @facet_queries = []
      @limit = nil
      @loaded = false
      @more_like_this = false
      @order = nil
      @results = ResultSet.new
      @start = 0
      @where_clauses = [] # will be joined by AND
    end

    ##
    # @return [Integer]
    #
    def count
      self.to_a.total_length
    end

    ##
    # @param fq [Array] or string
    # @return [ActiveMedusa::Relation] self
    #
    def facet(fq)
      if fq === false
        @facet = false
      elsif fq.blank?
        # noop
      elsif fq.respond_to?(:each)
        @facet_queries += fq.reject{ |v| v.blank? }
      elsif fq.respond_to?(:to_s)
        @facet_queries << fq.to_s
      end
      self
    end

    def first
      @limit = 1
      self.to_a.first
    end

    ##
    # @param limit [Integer]
    # @return [ActiveMedusa::Relation] self
    #
    def limit(limit)
      @limit = limit
      self
    end

    def method_missing(name, *args, &block)
      if @results.respond_to?(name)
        self.to_a.send(name, *args, &block)
      else
        super
      end
    end

    ##
    # Activates a "more like this" query. See the documentation for more
    # information.
    #
    # @return [ActiveMedusa::Relation] self
    #
    def more_like_this
      @more_like_this = true
      @facet = false
      self
    end

    ##
    # @param order [Hash|String]
    # @return [ActiveMedusa::Entity] self
    #
    def order(order)
      if order.kind_of?(Hash)
        order = "#{order.keys.first} #{order[order.keys.first]}"
      else
        order = order.to_s
        order += ' asc' if !order.end_with?(' asc') and
            !order.end_with?(' desc')
      end
      @order = order
      self
    end

    def respond_to_missing?(method_name, include_private = false)
      @results.respond_to?(method_name) || super
    end

    ##
    # @param start [Integer]
    # @return [ActiveMedusa::Entity] self
    #
    def start(start)
      @start = start
      self
    end

    ##
    # @param [String] Transaction URL
    #
    def use_transaction_url(url)
      self.transaction_url = url
      self
    end

    ##
    # @param where [Hash|String]
    # @return [ActiveMedusa::Entity] self
    #
    def where(where)
      if where.blank?
        # noop
      elsif where.kind_of?(Hash)
        @where_clauses += where.reject{ |k, v| k.blank? or v.blank? }.
            map{ |k, v| "#{k}:\"#{v}\"" }
      elsif where.respond_to?(:to_s)
        @where_clauses << where.to_s
      end
      self
    end

    ##
    # @return [ActiveMedusa::ResultSet]
    #
    def to_a
      load
      @results
    end

    private

    def load
      if @calling_class and !@loaded
        # if @calling_class is ActiveMedusa::Container, query across all
        # entities.
        if @calling_class != ActiveMedusa::Container
          # limit the query to the calling class
          @where_clauses << "#{Configuration.instance.solr_class_field}:\""\
          "#{@calling_class.entity_class_uri}\""
        end
        params = {
            q: @where_clauses.join(' AND '),
            df: Configuration.instance.solr_default_search_field,
            fl: '*,score',
            start: @start,
            sort: @order,
            rows: @limit
        }
        if @more_like_this
          params['mlt.fl'] = Configuration.instance.solr_default_search_field
        elsif @facet
          params[:facet] = true
          params['facet.mincount'] = 1
          params['facet.field'] = Configuration.instance.solr_facet_fields
          params[:fq] = @facet_queries
        end

        endpoint = @more_like_this ?
            Configuration.instance.solr_more_like_this_endpoint.gsub(/\//, '') :
            'select'
        solr_result = Solr.client.get(endpoint, params: params)
        @solr_request = solr_result['request']
        @solr_response = solr_result['response']
        @results.facet_fields = solr_facet_fields_to_objects(
            solr_result['facet_counts']['facet_fields']) if @facet
        @results.total_length = solr_result['response']['numFound'].to_i
        solr_result['response']['docs'].each do |doc|
          begin
            if @calling_class == ActiveMedusa::Container
              predicate = doc[Configuration.instance.solr_class_field.to_s]
              instantiable = ActiveMedusa::Base.send(:class_of_predicate,
                                                     predicate)
            else
              instantiable = @calling_class
            end
            if instantiable
              entity = instantiable.new(solr_representation: doc,
                                        repository_url: doc['id'],
                                        score: doc['score'])
              url = doc['id']
              url = transactional_url(url) if self.transaction_url.present?
              f4_response = Fedora.client.get(
                  url, nil, { 'Accept' => 'application/n-triples' })
              graph = RDF::Graph.new
              graph.from_ntriples(f4_response.body)
              entity.send(:populate_from_graph, graph)
              @results << entity
            else
              Configuration.instance.logger.
                  error("Unable to instantiate a class associated with "\
                  "#{doc[Configuration.instance.solr_class_field.to_s]}")
              @results.total_length -= 1
            end
          rescue HTTPClient::BadResponseError => e
            # This probably means that the item was deleted from the
            # repository and the delete did not propagate to Solr for some
            # reason. There is nothing we can do, so swallow it and log it
            # to avoid disrupting the user experience.
            Configuration.instance.logger.
                error("Item present in Solr result is missing from "\
                "repository: #{e.message}")
            @results.total_length -= 1
          end
        end
        @loaded = true
      end
    end

    def solr_facet_fields_to_objects(fields)
      facets = []
      fields.each do |field, terms|
        facet = Facet.new
        facet.field = field
        (0..terms.length - 1).step(2) do |i|
          # hide the below F4-managed URL from the DC format facet
          next if terms[i] == 'http://fedora.info/definitions/v4/repository#jcr/xml'
          term = Facet::Term.new
          term.name = terms[i]
          term.label = terms[i]
          term.count = terms[i + 1]
          term.facet = facet
          facet.terms << term
        end
        facets << facet
      end
      facets
    end

  end

end
