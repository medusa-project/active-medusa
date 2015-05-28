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
    include Relationships
    include Transactions

    define_model_callbacks :create, :delete, :load, :save, :update,
                           only: [:after, :before]

    @@entity_class_uris = Set.new
    @@rdf_properties = Set.new

    # @!attribute container_url
    #   @return [String] The URL of the entity's parent container.
    attr_accessor :container_url

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

    # @!attribute transaction_url
    #   @return [String] URL of the transaction in which the entity exists.
    attr_accessor :transaction_url

    # @!attribute uuid
    #   @return [String] The instance's repository-assigned UUID.
    attr_accessor :uuid
    alias_method :id, :uuid

    validates :uuid, allow_blank: true, length: { minimum: 36, maximum: 36 }

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
    # Supplies a "property" keyword to subclasses which maps a Ruby property to
    # an RDF predicate and Solr field. Example:
    #
    #     rdf_property :full_text, predicate: 'http://example.org/fullText',
    #                  xs_type: :string, solr_field: 'full_text'
    #
    # @param name [Symbol] Property name
    # @param options [Hash] Hash with the following keys:
    #        `:predicate`: RDF predicate URI; `:xs_type`: One of:
    #        `:string`, `:integer`, `:boolean`, `:anyURI`; `:solr_field`
    #
    def self.rdf_property(name, options)
      @@rdf_properties << { class: self,
                            name: name,
                            predicate: options[:predicate],
                            type: options[:xs_type],
                            solr_field: options[:solr_field] }
      instance_eval { attr_accessor name }
    end

    ##
    # Executes a block within a transaction. Use like:
    #
    #     ActiveMedusa::Base.transaction do |transaction_url|
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
    #
    def initialize(params = {})
      @belongs_to = {} # entity name => ActiveMedusa::Relation TODO: move to Relationships
      @has_many = {} # entity name => ActiveMedusa::Relation TODO: move to Relationships
      @destroyed = false
      @loaded = false
      @persisted = false
      params.except(:id, :uuid).each do |k, v|
        send("#{k}=", v) if respond_to?("#{k}=")
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
    #
    def delete(also_tombstone = false)
      if @persisted and !@destroyed
        url = transactional_url(self.repository_url)
        if url
          run_callbacks :delete do
            url = url.chomp('/')
            client = Fedora.client
            client.delete(url)
            client.delete("#{url}/fcr:tombstone") if also_tombstone
            @destroyed = true
            @persisted = false

            # TODO: delete relationships
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
    # Handles `find_by_x` calls. # TODO: move this to Querying
    #
    def method_missing(name, *args, &block)
      name_s = name.to_s
      if self.respond_to?(name)
        prop = @@rdf_properties.select{ |p| p[:name] == name_s }.first
        if prop
          return self.where(prop[:solr_field] => args[0]).
              use_transaction_url(args[1]).first
        end
      end
      super
    end

    ##
    # @return [Boolean]
    #
    def persisted?
      @persisted and !@destroyed
    end

    def reload!
      populate_from_graph(fetch_current_graph) if self.persisted?
    end

    ##
    # Overridden to handle `find_by_x` calls.
    #
    def respond_to?(sym, include_private = false)
      sym_s = sym.to_s
      if sym_s.start_with?('find_by_') and @@rdf_properties.
            select{ |p| p[:class] == self.class and p[:name].to_s == sym_s }.any?
        return true
      end
      super
    end

    ##
    # Persists the entity. For this to work, The entity must already have a
    # UUID (for existing entities) *or* it must have a parent container URL
    # (for new entities).
    #
    # @raise [RuntimeError]
    #
    def save
      raise 'Validation error' unless self.valid?
      raise 'Cannot save a destroyed object.' if self.destroyed?
      run_callbacks :save do
        if self.uuid
          save_existing
        elsif self.container_url
          save_new
        else
          raise 'UUID and container URL are both nil. One or the other is '\
          'required.'
        end
        @persisted = true
      end
    end

    alias_method :save!, :save

    ##
    # @param params [Hash]
    #
    def update(params)
      run_callbacks :update do
        params.except(:id, :uuid).each do |k, v|
          send("#{k}=", v) if respond_to?("#{k}=")
        end
        self.save
      end
    end

    ##
    # @param params [Hash]
    #
    def update!(params)
      run_callbacks :update do
        params.except(:id, :uuid).each do |k, v|
          send("#{k}=", v) if respond_to?("#{k}=")
        end
        self.save!
      end
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

    def fetch_current_graph
      graph = RDF::Graph.new
      url = self.repository_metadata_url # already transactionalized
      if url
        response = Fedora.client.get(
            url, nil, { 'Accept' => 'application/n-triples' })
        graph.from_ntriples(response.body)
      end
      graph
    end

    ##
    # Saves an existing node.
    #
    # @raise [RuntimeError]
    #
    def save_existing
      self.rdf_graph = populate_graph(fetch_current_graph)
      url = transactional_url(self.repository_metadata_url)
      body = self.rdf_graph.to_ttl
      headers = { 'Content-Type' => 'text/turtle' }
      # TODO: prefixes http://blog.datagraph.org/2010/04/parsing-rdf-with-ruby
      begin
        Fedora.client.put(url, body, headers)
      rescue HTTPClient::BadResponseError => e
        raise "#{e.res.status}: #{e.res.body}"
      end
    end

    ##
    # Creates a new node.
    #
    # @raise [RuntimeError]
    #
    def save_new
      raise 'Subclasses must override save_new()'
    end

    private

    ##
    # @param predicate [String]
    # @return [Class]
    #
    def self.class_of_predicate(predicate)
      # load all entities in order to populate @@entity_class_uris
      Dir.glob(File.join(Configuration.instance.entity_path, '*.rb')).each do |file|
        require_relative(file)
      end
      d = @@entity_class_uris.select{ |u| u[:predicate] == predicate }.first
      d ? d[:class] : nil
    end

    ##
    # @param loaded [Boolean]
    #
    def loaded=(loaded)
      run_callbacks :load do
        @loaded = loaded
      end
    end

    ##
    # Populates the instance with data from an RDF graph.
    #
    # @param graph [RDF::Graph]
    #
    def populate_from_graph(graph)
      self.rdf_graph = graph

      self.uuid = graph.any_object('http://fedora.info/definitions/v4/repository#uuid').to_s
      self.container_url = graph.any_object('http://fedora.info/definitions/v4/repository#hasParent').to_s

      # set values of subclass `rdf_property` definitions
      @@rdf_properties.select{ |p| p[:class] == self.class }.each do |prop|
        value = graph.any_object(prop[:predicate])
        if prop[:xs_type] == :boolean
          value = ['true', '1'].include?(value.to_s)
        else
          value = value.to_s
        end
        send("#{prop[:name]}=", value)
      end

      self.loaded = true
      @persisted = true
    end

    ##
    # Populates an RDF::Graph for sending to Fedora.
    #
    # @param graph [RDF::Graph]
    # @return [RDF::Graph] Input graph
    def populate_graph(graph)
      # add properties from subclass rdf_property definitions
      @@rdf_properties.select{ |p| p[:class] == self.class }.each do |prop|
        graph.delete([nil, RDF::URI(prop[:predicate]), nil])
        value = send(prop[:name])
        case prop[:type].to_sym
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
      @belongs_to.each do |entity_name, entity|
        predicate = self.class.get_belongs_to_defs.
            select{ |d| d[:entity] == entity_name.to_s }.first[:predicate]
        graph.delete([nil, RDF::URI(predicate), nil])
        graph << RDF::Statement.new(
            RDF::URI(), RDF::URI(predicate), RDF::URI(entity.repository_url)) if entity
      end
      graph
    end

  end

end
