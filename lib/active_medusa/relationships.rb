require 'set'

module ActiveMedusa

  module Relationships

    attr_reader :belongs_to_instances

    def initialize
      @belongs_to_instances = {} # Class => entity instance
    end

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      ##
      # [Set<ActiveMedusa::Association>]
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
      # @param options [Hash] Options hash.
      # @option options [String] :rdf_predicate
      # @option options [String, Symbol] :solr_field
      # @option options [String, Symbol] :name Specifies the name of the
      #   accessor method (optional).
      # @option options [String] :class_name Specifies the name of the owning
      #   class (optional).
      #
      def belongs_to(entity, options)
        raise 'Cannot define a `belongs_to` relationship named `parent`.' if
            [options[:name], entity].map{ |e| e.to_s.downcase }.include?('parent')
        [:rdf_predicate, :solr_field].each do |opt|
          raise "belongs_to statement is missing #{opt} option" unless
              options.has_key?(opt)
        end

        if options[:class_name]
          entity_class = Object.const_get(options[:class_name].to_s)
        else
          entity_class = Object.const_get(entity.to_s.camelize)
        end
        self_ = self
        self.class.instance_eval do
          @@associations << ActiveMedusa::Association.new(
              options.merge(name: options[:name] || entity,
                            source_class: self_,
                            type: ActiveMedusa::Association::Type::BELONGS_TO,
                            target_class: entity_class))
        end

        # Define a lazy getter method to access the target of the relationship
        define_method(options[:name] || entity_class.to_s.underscore.split('/').last) do
          owner = @belongs_to_instances[entity_class]
          unless owner
            association = @@associations.
                select{ |a| a.source_class == self.class and
                a.target_class == entity_class and
                a.type == ActiveMedusa::Association::Type::BELONGS_TO }.first
            self.rdf_graph.each_statement do |st|
              if st.predicate.to_s == association.rdf_predicate
                owner = association.target_class.find(st.object.to_s)
                @belongs_to_instances[entity_class] = owner
                break
              end
            end
          end
          owner
        end

        # Define a setter method to access the target of the relationship
        define_method("#{options[:name] || entity_class.to_s.underscore.split('/').last}=") do |owner|
          raise 'Owner must descend from ActiveMedusa::Container' if owner and
              !owner.kind_of?(ActiveMedusa::Container)
          @belongs_to_instances[entity_class] = owner # store a reference to the owner
        end
      end

      ##
      # @param entities [Symbol] Pluralized `ActiveMedusa::Container` subclass
      #   name
      # @param options [Hash] Options hash.
      # @option options [String] :class_name (Optional)
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
              source_class: self_,
              type: ActiveMedusa::Association::Type::HAS_MANY,
              target_class: entity_class)
        end

        ##
        # @param entities [String, Symbol]
        # @return [ActiveMedusa::Relation]
        #
        define_method(entities) do
          solr_rel_field = self.class.associations.
              select{ |a| a.source_class == entity_class and
              a.target_class == self.class and
              a.type == ActiveMedusa::Association::Type::BELONGS_TO }.first.solr_field
          entity_class.all.facet(false).
              where(solr_rel_field => self.repository_url)
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
            child = ActiveMedusa::Container.find(st.object.to_s)
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
            @parent = ActiveMedusa::Container.find(st.object.to_s)
            break
          end
        end
      end
      @parent
    end

  end

end
