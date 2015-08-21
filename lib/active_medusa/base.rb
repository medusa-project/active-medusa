require 'active_medusa/association'
require 'active_medusa/fedora'
require 'active_medusa/property'
require 'active_medusa/querying'
require 'active_medusa/solr'
require 'active_medusa/relationships'
require 'active_medusa/transactions'
require 'active_model'
require 'active_support/inflector'
require 'globalid'
require 'rdf'
require 'rdf/turtle'

module ActiveMedusa

  ##
  # Abstract class from which all ActiveMedusa entities should inherit.
  #
  class Base

    extend ActiveModel::Callbacks
    include ActiveModel::Model
    include GlobalID::Identification
    include Querying
    include Relationships
    include Transactions

    REJECT_PARAMS = [:id]

    define_model_callbacks :create, :destroy, :load, :save, :update,
                           only: [:after, :before]

    @@entity_class_uris = Set.new
    @@properties = Set.new

    # @!attribute id
    #   @return [String] The instance's repository ID.
    attr_accessor :id
    alias_method :repository_url, :id
    alias_method :repository_url=, :id=

    # @!attribute parent_url
    #   @return [String] The URL of the entity's parent container.
    attr_accessor :parent_url

    # @!attribute rdf_graph
    #   @return [RDF::Graph] RDF graph containing the instance's repository
    #           properties.
    attr_accessor :rdf_graph

    # @!attribute requested_slug
    #   @return [String] The requested Fedora URI last path component for new
    #           entities.
    attr_accessor :requested_slug

    # @!attribute score
    #   @return [Float] Float populated by `ActiveMedusa::Relation` in the
    #                   context of query results; not persisted.
    attr_accessor :score

    # @!attribute transaction_url
    #   @return [String] URL of the transaction in which the entity exists.
    attr_accessor :transaction_url

    ##
    # @param predicate [String]
    # @return [Class]
    #
    def self.class_of_predicate(predicate)
      d = @@entity_class_uris.select{ |u| u[:predicate] == predicate }.first
      d ? d[:class] : nil
    end

    ##
    # @param params [Hash]
    # @return [ActiveMedusa::Base]
    # @raise [ActiveMedusa::RecordInvalid]
    #
    def self.create(params = {})
      instance = self.new(params)
      instance.save
      instance
    end

    ##
    # @param params [Hash]
    # @return [ActiveMedusa::Base]
    # @raise [ActiveMedusa::RecordInvalid]
    #
    def self.create!(params = {})
      instance = self.new(params)
      instance.save!
      instance
    end

    class << self
      def entity_class_uri(name = nil)
        if name
          @entity_class_uri = name
          @@entity_class_uris << { predicate: name, class: self }
        end
        @entity_class_uri
      end
    end

    ##
    # @param repository_url [String]
    # @return [ActiveMedusa::Base] `ActiveMedusa::Base` subclass
    # @raise [RuntimeError, RDF::ReaderError]
    #
    def self.load(repository_url)
      # find the class to instantiate
      f4_response = Fedora.client.get(
          repository_url.chomp('/') + '/fcr:metadata', nil,
          { 'Accept' => 'application/n-triples' })
      graph = RDF::Graph.new
      graph.from_ntriples(f4_response.body)
      predicate = nil
      graph.each_statement do |st|
        if st.predicate.to_s == Configuration.instance.class_predicate.to_s
          predicate = st.object.to_s
          break
        end
      end

      if predicate
        instantiable = ActiveMedusa::Base.class_of_predicate(predicate)
        if instantiable
          entity = instantiable.new(repository_url: repository_url)
          entity.send(:populate_self_from_graph, graph)
          return entity
        else
          raise "Unable to instantiate a(n) #{instantiable}"
        end
      else
        raise "Unable to find a class associated with this URI"
      end
      nil
    end

    ##
    # @return [Set<ActiveMedusa::Property>]
    #
    def self.properties
      @@properties
    end

    ##
    # Supplies a "property" keyword to subclasses which maps a Ruby property to
    # an RDF predicate and Solr field. Example:
    #
    #     property :full_text, rdf_predicate: 'http://example.org/fullText',
    #              type: :string, solr_field: 'full_text'
    #
    # @param name [Symbol] Property name
    # @param options [Hash] Options hash.
    # @option options [String] :rdf_predicate RDF predicate URI.
    # @option options [Symbol] :type One of: `:string`, `:integer`,
    #   `:float`, `:boolean`, `:anyURI`
    # @option options [Symbol, String] :solr_field The Solr field in which
    #   the property is indexed.
    # @raise [RuntimeError] If any of the required options are missing
    #
    def self.property(name, options)
      [:rdf_predicate, :type, :solr_field].each do |opt|
        raise "property statement is missing #{opt} option" unless
            options.has_key?(opt)
      end
      @@properties << Property.new(options.merge(class: self, name: name))
      instance_eval { attr_accessor name }
    end

    ##
    # @param params [Hash]
    # @raise [ArgumentError]
    #
    def initialize(params = {})
      raise ArgumentError, 'Invalid arguments' unless params.kind_of?(Hash)
      super() # call module initializers
      @destroyed = @loaded = @persisted = false
      @rdf_graph = new_rdf_graph
      params.except(*REJECT_PARAMS).each do |k, v|
        if k.to_sym == :rdf_graph
          # copy statements from the graph instead of overwriting the
          # instance's graph (which may not be empty)
          v.each_statement do |st|
            self.rdf_graph << [RDF::URI(), st.predicate, st.object]
          end
        elsif respond_to?("#{k}=")
          send("#{k}=", v)
        end
      end
    end

    ##
    # @return [Time]
    #
    def created_at
      self.rdf_graph.each_statement do |statement|
        if statement.predicate.to_s ==
            'http://fedora.info/definitions/v4/repository#created'
          return Time.parse(statement.object.to_s)
        end
      end
      nil
    end

    ##
    # Destroys the instance's corresponding repository node, marks the instance
    # as destroyed, and freezes it.
    #
    # @param options [Hash] Options hash
    # @option options [Boolean] :also_tombstone Also deletes the repository
    #   node's `fcr:tombstone`.
    # @return [Boolean]
    #
    def destroy(options = {})
      if @persisted and !@destroyed
        url = transactional_url(self.repository_url)
        if url
          run_callbacks :destroy do
            url = url.chomp('/')
            client = Fedora.client
            client.delete(url)
            client.delete("#{url}/fcr:tombstone") if options[:also_tombstone]
            @destroyed = true
            @persisted = false
            self.freeze
          end
        end
        return true
      end
      false
    end

    alias_method :destroy!, :destroy
    alias_method :delete, :destroy

    ##
    # @return [Boolean]
    #
    def destroyed?
      @destroyed
    end

    ##
    # @return [Boolean]
    #
    def persisted?
      @persisted and !@destroyed
    end

    def reload!
      populate_self_from_graph(fetch_current_graph)
    end

    ##
    # Persists the entity. For this to work, The entity must already have a
    # repository URL (for existing entities) *or* it must have a parent
    # container URL (for new entities).
    #
    # @raise [RuntimeError]
    # @raise [ActiveMedusa::RecordInvalid]
    #
    def save
      raise 'Cannot save a destroyed object.' if self.destroyed?
      run_callbacks :save do
        if self.repository_url
          save_existing
        elsif self.parent_url
          save_new
        else
          raise 'repository_url and parent_url are both nil. One or the other '\
          'is required.'
        end
        self.reload!
      end
    end

    alias_method :save!, :save

    ##
    # @param params [Hash]
    # @raise [RuntimeError]
    # @raise [ActiveMedusa::RecordInvalid]
    #
    def update(params)
      params.except(*REJECT_PARAMS).each do |k, v|
        send("#{k}=", v) if respond_to?("#{k}=")
      end
      self.save
    end

    ##
    # @param params [Hash]
    # @raise [RuntimeError]
    # @raise [ActiveMedusa::RecordInvalid]
    #
    def update!(params)
      params.except(*REJECT_PARAMS).each do |k, v|
        send("#{k}=", v) if respond_to?("#{k}=")
      end
      self.save!
    end

    ##
    # @return [Time]
    #
    def updated_at
      self.rdf_graph.each_statement do |statement|
        if statement.predicate.to_s ==
            'http://fedora.info/definitions/v4/repository#lastModified'
          return Time.parse(statement.object.to_s)
        end
      end
      nil
    end

    protected

    ##
    # @return [RDF::Graph,nil] The current graph, or `nil` if there is none.
    #
    def fetch_current_graph
      url = self.repository_metadata_url # already transactionalized
      if url
        graph = RDF::Graph.new
        response = Fedora.client.get(
            url, nil, { 'Accept' => 'application/n-triples' })
        graph.from_ntriples(response.body)
        return graph
      end
      nil
    end

    ##
    # @return [RDF::Graph]
    #
    def new_rdf_graph
      graph = RDF::Graph.new
      graph << RDF::Statement.new(
          RDF::URI(), RDF::URI(Configuration.instance.class_predicate),
          RDF::URI(self.class.entity_class_uri))
      graph
    end

    ##
    # Populates an RDF::Graph for sending to Fedora.
    #
    # @param graph [RDF::Graph]
    # @return [RDF::Graph] Input graph
    #
    def populate_outgoing_graph(graph)
      # add properties from subclass property definitions
      @@properties.select{ |p| p.class == self.class }.each do |prop|
        graph.delete([nil, RDF::URI(prop.rdf_predicate), nil])
        value = send(prop.name)
        case prop.type.to_sym
          when :boolean
            if value != nil
              value = %w(true 1).include?(value.to_s) ? 'true' : 'false'
            end
          when :anyURI
            value = RDF::URI(value)
          else
            value = value.to_s
        end
        graph << RDF::Statement.new(
            RDF::URI(), RDF::URI(prop.rdf_predicate), value) if value.present?
      end

      # add properties from subclass belongs_to relationships
      belongs_to_instances.each do |entity_name, entity|
        assoc = self.class.associations.
            select{ |a| a.source_class == self.class and
            a.type == ActiveMedusa::Association::Type::BELONGS_TO and
            a.target_class == entity.class }.first
        if assoc
          graph.delete([nil, RDF::URI(assoc.rdf_predicate), nil])
          graph << [RDF::URI(), RDF::URI(assoc.rdf_predicate),
                    RDF::URI(entity.repository_url)] if entity
        end

      end

      graph
    end

    ##
    # Populates the instance with data from an RDF graph.
    #
    # @param graph [RDF::Graph]
    #
    def populate_self_from_graph(graph)
      self.rdf_graph = graph

      self.parent_url = graph.any_object('http://fedora.info/definitions/v4/repository#hasParent').to_s

      # set values of subclass `property` definitions
      @@properties.select{ |p| p.class == self.class }.each do |prop|
        value = graph.any_object(prop.rdf_predicate)
        case prop.type
          when :boolean
            value = %w(true 1).include?(value.to_s)
          when :integer
            value = value.to_s.to_i
          when :float
            value = value.to_s.to_f
          else
            value = value.to_s
        end
        send("#{prop.name}=", value)
      end

      self.loaded = true
      @persisted = true
    end

    ##
    # Saves an existing node.
    #
    # @raise [RuntimeError]
    # @raise [ActiveMedusa::RecordInvalid]
    #
    def save_existing
      run_callbacks :update do
        populate_outgoing_graph(self.rdf_graph)
        raise ActiveMedusa::RecordInvalid unless self.valid?
        url = transactional_url(self.repository_metadata_url)
        body = self.rdf_graph.to_ttl
        headers = { 'Content-Type' => 'text/turtle' }
        Fedora.client.put(url, body, headers)
      end
    end

    ##
    # Abstract method that subclasses must override.
    #
    # @raise [RuntimeError]
    #
    def save_new
      raise 'Subclasses must override save_new()'
    end

    private

    ##
    # @param loaded [Boolean]
    #
    def loaded=(loaded)
      run_callbacks :load do
        @loaded = loaded
      end
    end

  end

end
