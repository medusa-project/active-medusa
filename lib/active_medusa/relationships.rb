require 'set'

module ActiveMedusa

  module Relationships

    attr_reader :belongs_to_instances
    attr_reader :has_binary_instances
    attr_reader :has_many_instances

    def initialize
      @belongs_to_instances = {} # Class => entity instance
      @has_binary_instances = {} # Class => Set
      @has_many_instances = {} # Class => ActiveMedusa::Relation
    end

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      ##
      # Set of `ActiveMedusa::Association`s
      #
      @@associations = Set.new

      ##
      # @return [Set<ActiveMedusa::Association>]
      #
      def associations
        @@associations
      end

      ##
      # @param entity [Symbol] `ActiveMedusa::Base` subclass name
      # @param options [Hash] Hash with the following required keys:
      #                `:predicate`, `:solr_field`; and the following optional
      #                keys: `:name` (specifies the name of the accessor
      #                 method), `:class_name`
      #
      def belongs_to(entity, options)
        raise 'Cannot define a `belongs_to` relationship named `parent`.' if
            [options[:name], entity].map{ |e| e.to_s.downcase }.include?('parent')

        if options[:class_name]
          entity_class = Object.const_get(options[:class_name].to_s)
        else
          entity_class = Object.const_get(entity.to_s.camelize)
        end
        self_ = self
        self.class.instance_eval do
          @@associations << ActiveMedusa::Association.new(
              name: options[:name],
              rdf_predicate: options[:predicate],
              solr_field: options[:solr_field],
              source_class: self_,
              type: ActiveMedusa::Association::Type::BELONGS_TO,
              target_class: entity_class)
        end

        # Define a lazy getter method to access the target of the relationship
        define_method(options[:name] || entity_class.to_s.underscore) do
          owner = @belongs_to_instances[entity_class]
          unless owner
            association = @@associations.
                select{ |a| a.source_class == self.class and
                a.target_class == entity_class and
                a.type == ActiveMedusa::Association::Type::BELONGS_TO }.first
            self.rdf_graph.each_statement do |st|
              if st.predicate.to_s == association.rdf_predicate
                owner = association.target_class.find_by_uri(st.object.to_s)
                @belongs_to_instances[entity_class] = owner
                break
              end
            end
          end
          owner
        end

        # Define a setter method to access the target of the relationship
        define_method("#{options[:name] || entity_class.to_s.underscore}=") do |owner|
          raise 'Owner must descend from ActiveMedusa::Container' unless
              owner.kind_of?(ActiveMedusa::Container)
          @belongs_to_instances[entity_class] = owner # store a reference to the owner

          if self.kind_of?(ActiveMedusa::Binary)
            owner.binaries_to_add << self
          end
        end
      end

      ##
      # @param entities [Symbol] Pluralized `ActiveMedusa::Container` subclass
      #                 name
      # @param options [Hash] Hash with the following keys: :predicate (only
      #                for binaries), :class_name (optional)
      #
      def has_many(entities, options = {})
        raise 'Cannot define a `has_many` relationship named `children`.' if
            entities.to_s == 'children'

        if options[:class_name]
          entity_class = Object.const_get(options[:class_name].to_s)
        else
          entity_class = Object.const_get(entities.to_s.singularize.camelize)
        end
        self_ = self
        self.class.instance_eval do
          @@associations << ActiveMedusa::Association.new(
              name: entities.to_s,
              rdf_predicate: options[:predicate],
              source_class: self_,
              type: ActiveMedusa::Association::Type::HAS_MANY,
              target_class: entity_class)
        end

        if entity_class.new.kind_of?(ActiveMedusa::Binary)
          ##
          # @param entities [String|Symbol]
          # @return [Set]
          #
          define_method(entities) do
            @has_binary_instances[entity_class] ||= Set.new
            @has_binary_instances[entity_class]
          end
        else
          ##
          # @param entities [String|Symbol]
          # @return [ActiveMedusa::Relation]
          #
          define_method(entities) do
            owned = @has_many_instances[entity_class] # Class => Relation
            unless owned
              solr_rel_field = entity_class.associations.
                  select{ |a| a.source_class == self.class and
                  a.target_class == entity_class and
                  a.type == ActiveMedusa::Association::Type::HAS_MANY }.first.solr_field
              owned = entity_class.where(solr_rel_field => self.repository_url)
              @has_many_instances[entity_class] = owned
            end
            owned
          end
        end
      end

    end

    ##
    # @return [ActiveMedusa::Relation] Relation of all LDP children for which
    # there exist corresponding `ActiveMedusa::Base` subclasses.
    #
    def children
      unless @children and @children.any?
        @children = ActiveMedusa::Relation.new(ActiveMedusa::Container)
        self.rdf_graph.each_statement do |st|
          if st.predicate.to_s == 'http://www.w3.org/ns/ldp#contains'
            # TODO: make this more efficient
            child = ActiveMedusa::Container.find_by_uri(st.object.to_s)
            @children << child if child
          end
        end
      end
      @children
    end

    ##
    # @return [ActiveMedusa::Base] `ActiveMedusa::Base` subclass
    #
    def parent
      unless @parent
        self.rdf_graph.each_statement do |st|
          if st.predicate.to_s ==
              'http://fedora.info/definitions/v4/repository#hasParent'
            @parent = ActiveMedusa::Container.find_by_uri(st.object.to_s)
            break
          end
        end
      end
      @parent
    end

  end

end
