require 'active_medusa/facet'
require 'active_medusa/result_set'
require 'active_medusa/solr'
require 'httpclient'

module ActiveMedusa

  ##
  # Query builder class, conceptually similar to [ActiveRecord::Relation].
  #
  class Relation

    # @!attribute solr_response
    #   @return [Hash]
    attr_reader :solr_response

    ##
    # @param caller [ActiveMedusa::Base] The calling entity, or `nil` to
    # initialize an "empty query", i.e. one that will return no results.
    #
    def initialize(caller = nil)
      @caller = caller
      @calling_class = caller.kind_of?(Class) ? caller : caller.class
      @facet = true
      @facetable_fields = Configuration.instance.solr_default_facetable_fields
      @facet_queries = []
      @filter_clauses = [] # will be joined by AND
      @limit = nil
      @more_like_this = false
      @omit_entity_query = false
      @order = nil
      @start = 0
      @where_clauses = [] # will be joined by AND
      reset_results
    end

    ##
    # @return [Integer]
    #
    def count
      self.to_a.total_length
    end

    ##
    # @param fq [Array, String]
    # @return [ActiveMedusa::Relation] self
    #
    def facet(fq)
      reset_results
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

    ##
    # @param fq [Hash, String]
    # @return [ActiveMedusa::Entity] self
    #
    def filter(fq)
      reset_results
      if fq.blank?
        # noop
      elsif fq.kind_of?(Hash)
        @filter_clauses += fq.reject{ |k, v| k.blank? or v.blank? }.
            map{ |k, v| "#{k}:\"#{v}\"" }
      elsif fq.respond_to?(:to_s)
        @filter_clauses << fq.to_s
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
      reset_results
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
      raise 'Caller is not set.' unless @caller
      reset_results
      @more_like_this = true
      @facet = false
      self.where(Configuration.instance.solr_uri_field => @caller.repository_url)
    end

    ##
    # Whether to omit the entity query from the Solr query. If false, calling
    # something like `MyEntity.where(..)` will automatically limit the query to
    # results of `MyEntity` type.
    #
    # The entity query is present by default.
    #
    # @param boolean [Boolean]
    # @return [ActiveMedusa::Relation] self
    #
    def omit_entity_query(boolean)
      @omit_entity_query = boolean
      self
    end

    ##
    # @param order [Hash, String]
    # @return [ActiveMedusa::Entity] self
    #
    def order(order)
      reset_results
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
      reset_results
      @start = start
      self
    end

    ##
    # @param where [Hash, String]
    # @return [ActiveMedusa::Entity] self
    #
    def where(where)
      reset_results
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
        if !@omit_entity_query and @calling_class != ActiveMedusa::Container and
            @calling_class.respond_to?(:entity_class_uri)
          # limit the query to the calling class
          @where_clauses << "#{Configuration.instance.solr_class_field}:\""\
          "#{@calling_class.entity_class_uri}\""
        end
        params = {
            'q' => @where_clauses.join(' AND '),
            'df' => Configuration.instance.solr_default_search_field,
            'fl' => "#{Configuration.instance.solr_uri_field},score",
            'fq' => @filter_clauses.join(' AND '),
            'start' => @start,
            'sort' => @order,
            'rows' => @limit
        }
        if @more_like_this
          params['mlt.fl'] = Configuration.instance.solr_default_search_field
          params['mlt.mindf'] = 1
          params['mlt.mintf'] = 1
          params['mlt.match.include'] = false
          params['fq'] = "#{Configuration.instance.solr_class_field}:\""\
          "#{@calling_class.entity_class_uri}\""
          endpoint = Configuration.instance.solr_more_like_this_endpoint.gsub(/\//, '')
        else
          endpoint = 'select'
          if @facet
            params['facet'] = true
            params['facet.mincount'] = 1
            params['facet.field'] = Configuration.instance.solr_facet_fields
            params['fq'] = @facet_queries
          end
        end

        @solr_response = Solr.client.get(endpoint, params: params)

        if !@more_like_this and @facet
          @results.facet_fields = solr_facet_fields_to_objects(
              @solr_response['facet_counts']['facet_fields'])
        end
        @results.total_length = @solr_response['response']['numFound'].to_i
        docs = @solr_response['response']['docs']
        docs.each do |doc|
          begin
            entity = ActiveMedusa::Base.load(doc['id'])
            entity.score = doc['score']
            @results << entity
          rescue HTTPClient::BadResponseError => e
            # This probably means that the item was deleted from the
            # repository and the delete did not propagate to Solr for some
            # reason. There is nothing we can do, so swallow it and log it
            # to avoid disrupting the user experience.
            Configuration.instance.logger.
                error("Item present in Solr result is missing from "\
                "repository: #{e.message}")
            @results.total_length -= 1
          rescue => e
            Configuration.instance.logger.error("#{e} (#{doc['id']})")
            @results.total_length -= 1
          end
        end
        @loaded = true
      end
    end

    ##
    # Reverts the instance to an "un-executed" state.
    #
    def reset_results
      @loaded = false
      @results = ResultSet.new
      @solr_response = nil
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
