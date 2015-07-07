require 'active_medusa/association'
require 'active_medusa/fedora'
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

    REJECT_PARAMS = [:id, :uuid]

    define_model_callbacks :create, :destroy, :load, :save, :update,
                           only: [:after, :before]

    @@entity_class_uris = Set.new
    @@rdf_properties = Set.new

    # @!attribute parent_url
    #   @return [String] The URL of the entity's parent container.
    attr_accessor :parent_url

    # @!attribute rdf_graph
    #   @return [RDF::Graph] RDF graph containing the instance's repository
    #           properties.
    attr_accessor :rdf_graph

    # @!attribute repository_url
    #   @return [String] The instance's repository URL outside of any
    #           transaction.
    attr_accessor :repository_url

    # @!attribute requested_slug
    #   @return [String] The requested Fedora URI last path component for new
    #           entities.
    attr_accessor :requested_slug

    # @!attribute score
    #   @return [Float] Float populated by `ActiveMedusa::Relation` in the
    #                   context of query results; not persisted.
    attr_accessor :score

    # @!attribute solr_representation
    #   @return [Hash] Hash of the instance's representation in Solr.
    attr_accessor :solr_representation

    # @!attribute transaction_url
    #   @return [String] URL of the transaction in which the entity exists.
    attr_accessor :transaction_url

    # @!attribute uuid
    #   @return [String] The instance's repository-assigned UUID.
    attr_accessor :uuid
    alias_method :id, :uuid

    validates :uuid, allow_blank: true, length: { minimum: 36, maximum: 36 }

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
    #
    def self.create(params = {})
      instance = self.new(params)
      instance.save
      instance
    end

    ##
    # @param params [Hash]
    # @return [ActiveMedusa::Base]
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
    # @return [Set] Set of hashes with the following keys:
    #        `:class`, `:name`, `:predicate`, `:xs_type`, `:solr_field`
    #
    def self.rdf_properties
      @@rdf_properties
    end

    ##
    # Supplies a "property" keyword to subclasses which maps a Ruby property to
    # an RDF predicate and Solr field. Example:
    #
    #     rdf_property :full_text, predicate: 'http://example.org/fullText',
    #                  xs_type: :string, solr_field: 'full_text'
    #
    # @param name [Symbol] Property name
    # @param options [Hash] Hash with the following keys:
    #        `:predicate`: RDF predicate URI; `:xs_type`: One of:
    #        `:string`, `:integer`, `:float`, `:boolean`, `:anyURI`;
    #        `:solr_field`
    # @raise RuntimeError If any of the required options are missing
    #
    def self.rdf_property(name, options)
      [:predicate, :xs_type, :solr_field].each do |opt|
        raise "rdf_property statement is missing #{opt} option" unless
            options.has_key?(opt)
      end
      @@rdf_properties << options.merge(class: self, name: name)
      instance_eval { attr_accessor name }
    end

    ##
    # Executes a block within a transaction. Use like:
    #
    #     ActiveMedusa::Base.transaction do |tx_url|
    #       # Code to run within the transaction.
    #       # Any raised errors will cause an automatic rollback.
    #     end
    #
    # @raise [RuntimeError]
    #
    def self.transaction
      client = Fedora.client
      url = create_transaction(client)
      begin
        yield url
      rescue => e
        rollback_transaction(url, client)
        raise e
      else
        commit_transaction(url, client)
      end
    end

    ##
    # @param params [Hash]
    # @raise [ArgumentError]
    #
    def initialize(params = {})
      raise ArgumentError, 'Invalid arguments' unless params.kind_of?(Hash)
      super() # call module initializers
      @destroyed = @loaded = @persisted = false
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
    # @param also_tombstone [Boolean]
    # @return [Boolean]
    #
    def delete(also_tombstone = false)
      if @persisted and !@destroyed
        url = transactional_url(self.repository_url)
        if url
          run_callbacks :destroy do
            url = url.chomp('/')
            client = Fedora.client
            client.delete(url)
            client.delete("#{url}/fcr:tombstone") if also_tombstone
            @destroyed = true
            @persisted = false
          end
        end
        return true
      end
      false
    end

    alias_method :destroy, :delete
    alias_method :destroy!, :delete

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
    # UUID (for existing entities) *or* it must have a parent container URL
    # (for new entities).
    #
    # @raise [RuntimeError]
    # @raise [ActiveModel::ValidationError]
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
    # @raise [ActiveModel::ValidationError]
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
    # @raise [ActiveModel::ValidationError]
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
    # Populates an RDF::Graph for sending to Fedora.
    #
    # @param graph [RDF::Graph]
    # @return [RDF::Graph] Input graph
    #
    def populate_outgoing_graph(graph)
      # add properties from subclass rdf_property definitions
      @@rdf_properties.select{ |p| p[:class] == self.class }.each do |prop|
        graph.delete([nil, RDF::URI(prop[:predicate]), nil])
        value = send(prop[:name])
        case prop[:xs_type].to_sym
          when :boolean
            if value != nil
              value = ['true', '1'].include?(value.to_s) ? 'true' : 'false'
            end
          when :anyURI
            value = RDF::URI(value)
          else
            value = value.to_s
        end
        graph << RDF::Statement.new(
            RDF::URI(), RDF::URI(prop[:predicate]), value) if value.present?
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

      self.uuid = graph.any_object('http://fedora.info/definitions/v4/repository#uuid').to_s
      self.parent_url = graph.any_object('http://fedora.info/definitions/v4/repository#hasParent').to_s

      # set values of subclass `rdf_property` definitions
      @@rdf_properties.select{ |p| p[:class] == self.class }.each do |prop|
        value = graph.any_object(prop[:predicate])
        case prop[:xs_type]
          when :boolean
            value = ['true', '1'].include?(value.to_s)
          when :integer
            value = value.to_s.to_i
          when :float
            value = value.to_s.to_f
          else
            value = value.to_s
        end
        send("#{prop[:name]}=", value)
      end

      self.loaded = true
      @persisted = true
    end

    ##
    # Saves an existing node.
    #
    # @raise [RuntimeError]
    # @raise [ActiveModel::ValidationError]
    #
    def save_existing
      run_callbacks :update do
        populate_outgoing_graph(self.rdf_graph)
        raise ActiveModel::ValidationError unless self.valid?
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
