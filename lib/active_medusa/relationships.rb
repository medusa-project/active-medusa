module ActiveMedusa

  module Relationships

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      ##
      # Set of hashes with the following required keys: `:entity`,
      # `:predicate`, `:solr_field`; and the following optional keys: `:name`
      # (specifies the name of the accessor method)
      #
      @@belongs_to_defs = Set.new

      ##
      # Set of hashes with the following required keys: `:entity`, `:predicate`
      #
      @@has_many_defs = Set.new

      ##
      # @param entity [Symbol] `ActiveMedusa::Base` subclass name
      # @param options [Hash] Hash with the following required keys:
      #                `:predicate`, `:solr_field`; and the following optional
      #                keys: `:name` (specifies the name of the accessor method)
      #
      def belongs_to(entity, options)
        if options[:name] == 'parent'
          raise 'Cannot define a `belongs_to` relationship named `parent`.'
        end

        entity = entity.to_s.downcase
        self.class.instance_eval do
          @@belongs_to_defs << options.merge(entity: entity)
        end

        # Define a lazy getter method to access the target of the relationship
        define_method(options[:name] || entity) do
          owner = @belongs_to[entity.to_sym]
          unless owner
            property = @@belongs_to_defs.select{ |p| p[:entity] == entity }.first
            entity_class = Object.const_get(entity.capitalize)
            self.rdf_graph.each_statement do |st|
              if st.predicate.to_s == property[:predicate]
                owner = entity_class.find_by_uri(st.object.to_s)
                @belongs_to[entity.to_sym] = owner
                break
              end
            end
          end
          owner
        end

        # Define a setter method to access the target of the relationship
        define_method("#{options[:name] || entity}=") do |value|
          @belongs_to[entity.to_sym] = value
        end
      end

      ##
      # @param entities [Symbol] Pluralized `ActiveMedusa::Base` subclass name
      # @param options [Hash] Hash with the following options: `:predicate`
      #
      def has_many(entities, options)
        if options[:entities] == 'children'
          raise 'Cannot define a `has_many` relationship named `children`.'
        end

        entity = entities.to_s.singularize
        self.class.instance_eval do
          @@has_many_defs << options.merge(entity: entity)
        end

        define_method(entities) do
          owned = @has_many[entities.to_sym]
          unless owned
            entity_class = Object.const_get(entity.capitalize)
            solr_rel_field = entity_class.get_belongs_to_defs.
                select{ |p| p[:entity] == self.class.to_s.downcase }.
                first[:solr_field]
            owned = entity_class.where(solr_rel_field => self.repository_url)
            @has_many[entities.to_sym] = owned
          end
          owned
        end
      end

      def get_belongs_to_defs
        @@belongs_to_defs
      end

    end

    ##
    # @return [Set] Set of all LDP children for which there exist corresponding
    # `ActiveMedusa::Base` subclasses.
    #
    def children
      unless @children.any?
        self.rdf_graph.each_statement do |st|
          if st.predicate.to_s == 'http://www.w3.org/ns/ldp#contains'
            # TODO: make this more efficient
            child = ActiveMedusa::Base.find_by_uri(st.object.to_s)
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
            @parent = ActiveMedusa::Base.find_by_uri(st.object.to_s)
            break
          end
        end
      end
      @parent
    end

  end

end
