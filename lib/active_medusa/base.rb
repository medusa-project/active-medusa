require 'active_medusa/fedora'
require 'active_medusa/querying'
require 'active_medusa/solr'
require 'active_medusa/sparql_update'
require 'active_medusa/transactions'
require 'active_model'
require 'active_support/inflector'
require 'globalid'
require 'rdf'

module ActiveMedusa

  ##
  # Abstract class from which all ActiveMedusa entities should inherit.
  #
  class Base

    extend ActiveModel::Callbacks
    include ActiveModel::Model
    include GlobalID::Identification
    include Querying
    include Transactions

    define_model_callbacks :create, :delete, :load, :save, :update,
                           only: [:after, :before]

    @@entity_uri = nil
    @@belongs_to = Set.new
    @@has_many = Set.new
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

    # @!attribute score
    #   @return [Float] Float populated by `ActiveMedusa::Relation`; not
    #           persisted.
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
    # @param entity [Symbol] `ActiveMedusa::Base` subclass name
    # @param predicate [String] RDF predicate
    #
    def self.belongs_to(entity, predicate)
      self.class.instance_eval do
        @@belongs_to << { entity: entity, predicate: predicate }
      end
    end

    ##
    # @param params [Hash]
    # @return [ActiveMedusa::Base]
    #
    def self.create(params = {})
      item = Item.new(params)
      item.save
      item
    end

    ##
    # @param params [Hash]
    # @return [ActiveMedusa::Base]
    #
    def self.create!(params = {})
      item = Item.new(params)
      item.save!
      item
    end

    ##
    # @param name [String] A unique name for the class. This will be used as
    # the value of `ActiveMedusa::Configuration.instance.solr_class_field` in
    # Solr.
    #
    def self.entity_uri(name = nil)
      if name
        @@entity_uri = name
      end
      @@entity_uri
    end

    ##
    # @param entity [Symbol] Pluralized `ActiveMedusa::Base` subclass name
    # @param predicate [String] RDF predicate
    #
    def self.has_many(entities, predicate)
      self.class.instance_eval do
        @@has_many << { entity: entities.to_s.pluralize(1),
                        predicate: predicate }
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
      # create accessors for subclass rdf_property statements
      @@rdf_properties.each do |prop|
        self.class.instance_eval { attr_accessor prop[:name] }
      end
      @children = Set.new
      @destroyed = false
      @persisted = false
      @rdf_graph = RDF::Graph.new
      params.except(:id, :uuid).each do |k, v|
        send("#{k}=", v) if respond_to?("#{k}=")
      end
    end

    ##
    # @return [Set]
    #
    def children
      unless @children.any?
        self.rdf_graph.each_statement do |st|
          if st.predicate.to_s == 'http://www.w3.org/ns/ldp#contains'
            @children << self.class.new(container_url: st.object.to_s)
          end
        end
      end
      @children
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
    # @param commit_immediately [Boolean]
    #
    def delete(also_tombstone = false, commit_immediately = true)
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

            if commit_immediately
              # wait for solr to get the delete
              # TODO: this is horrible
              # (also doing this in save())
              sleep 2
              Solr.client.commit
            end
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
    # @return [ActiveMedusa::Relation]
    #
    def more_like_this
      ActiveMedusa::Relation.new(self.class).more_like_this
    end

    def parent
      unless @parent
        self.rdf_graph.each_statement do |st|
          if st.predicate.to_s ==
              'http://fedora.info/definitions/v4/repository#hasParent'
            # TODO: self.class is wrong; should be the type of the node based
            # on its Config.instance.class_predicate
            #@parent = self.class.new(container_url: st.object.to_s)
            @parent = self.class.find_by_uri(st.object.to_s)
            break
          end
        end
      end
      @parent
    end

    ##
    # @return [Boolean]
    #
    def persisted?
      @persisted and !@destroyed
    end

    def reload!
      if self.persisted?
        url = transactional_url(self.repository_url)
        response = Fedora.client.get(
            url, nil, { 'Accept' => 'application/n-triples' })
        graph = RDF::Graph.new
        graph.from_ntriples(response.body)
        populate_from_graph(graph)
      end
    end

    ##
    # Persists the entity. For this to work, The entity must already have a
    # UUID (for existing entities) *or* it must have a parent container URL
    # (for new entities).
    #
    # @param commit_immediately [Boolean]
    # @raise [RuntimeError]
    #
    def save(commit_immediately = true) # TODO: look into Solr soft commits
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
        if commit_immediately
          # wait for solr to get the add
          # TODO: this is horrible (also doing it in delete())
          sleep 2
          Solr.client.commit
          self.reload!
        end
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
      end
    end

    ##
    # @param params [Hash]
    #
    def update!(params)
      self.update(params)
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

    private

    ##
    # Called by `Relation` via `send()`.
    #
    # @param loaded [Boolean]
    #
    def loaded(loaded)
      run_callbacks :load do
        # noop
      end
    end

    ##
    # Populates the instance with data from an RDF graph.
    #
    # @param graph [RDF::Graph]
    #
    def populate_from_graph(graph)
      graph.each_statement do |statement|
        if statement.predicate.to_s ==
            'http://fedora.info/definitions/v4/repository#uuid'
          self.uuid = statement.object.to_s
        end
        self.rdf_graph << statement
      end
      # add properties from subclass property definitions (see
      # `rdf_property`)
      @@rdf_properties.select{ |p| p[:class] == self.class }.each do |prop|
        graph.each_triple do |subject, predicate, object|
          if predicate.to_s == prop[:predicate]
            if prop[:xs_type] == :boolean
              value = ['true', '1'].include?(object.to_s)
            else
              value = object.to_s
            end
            send("#{prop[:name]}=", value)
            break
          end
        end
      end
      @persisted = true
    end

    ##
    # Updates an existing node.
    #
    def save_existing
      url = transactional_url(self.repository_url)
      Fedora.client.patch(url, to_sparql_update.to_s,
                          { 'Content-Type' => 'application/sparql-update' })
    end

    ##
    # Creates a new node.
    #
    def save_new
      run_callbacks :create do
        url = transactional_url(self.container_url)
        # As of version 4.1, Fedora doesn't like to accept triples via POST for
        # some reason; it just returns 201 Created regardless of the
        # Content-Type header and body content. I'm probably doing something
        # wrong. So, instead, we will POST to create an empty container, and
        # then update that.
        headers = { 'Content-Type' => 'application/n-triples' }
        headers['Slug'] = self.requested_slug if self.requested_slug
        response = Fedora.client.post(url, nil, headers)
        self.repository_url = nontransactional_url(response.header['Location'].first)
        self.requested_slug = nil
        save_existing
      end
    end

    ##
    # Generates a `SPARQLUpdate` to send the instance's current properties to
    # the repository.
    #
    # @return [ActiveMedusa::SPARQLUpdate]
    #
    def to_sparql_update
      update = SPARQLUpdate.new
      update.prefix('indexing', 'http://fedora.info/definitions/v4/indexing#').
          delete('<>', '<indexing:hasIndexingTransformation>', '?o', false).
          insert(nil, 'indexing:hasIndexingTransformation',
                 Configuration.instance.fedora_indexing_transformation)
      update.prefix('rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#').
          delete('<>', '<rdf:type>', 'indexing:Indexable', false).
          insert(nil, 'rdf:type', 'indexing:Indexable', false)
      update.delete('<>', "<#{Configuration.instance.class_predicate}>", '?o', false).
          insert(nil, "<#{Configuration.instance.class_predicate}>",
                 "<#{self.class.entity_uri}>", false) # TODO: conditionally escape depending on whether it's a URI

      self.rdf_graph.each_statement do |statement|
        # exclude repository-managed predicates from the update
        next if Fedora::MANAGED_PREDICATES.
            select{ |p| statement.predicate.to_s.start_with?(p) }.any?
        # exclude subclass-managed predicates from the update
        next if @@rdf_properties.select{ |p| p[:class] == self.class }.
            map{ |p| p[:predicate] }.include?(statement.predicate.to_s)

        update.delete('<>', "<#{statement.predicate.to_s}>", '?o', false).
            insert(nil, "<#{statement.predicate.to_s}>",
                   statement.object.to_s)
      end

      # add properties from subclass rdf_property definitions
      @@rdf_properties.select{ |p| p[:class] == self.class }.each do |prop|
        update.delete('<>', "<#{prop[:predicate]}>", '?o', false)
        value = send(prop[:name])
        case prop[:xs_type]
          when :boolean
            value = ['true', '1'].include?(value.to_s) ? 'true' : 'false'
            update.insert(nil, "<#{prop[:predicate]}>", value)
          when :anyURI
            update.insert(nil, "<#{prop[:predicate]}>", "<#{value}>", false) if
                value.present?
          else
            update.insert(nil, "<#{prop[:predicate]}>", value) if value.present?
        end
      end

      update
    end

  end

end
