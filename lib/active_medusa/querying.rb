require 'active_medusa/configuration'
require 'active_medusa/relation'

module ActiveMedusa

  ##
  # Defines finder methods on [Base].
  #
  module Querying

    def self.included(mod)
      mod.extend ClassMethods
    end

    module ClassMethods

      ##
      # @return [ActiveMedusa::Relation]
      #
      def all
        Relation.new(self)
      end

      ##
      # @param id [String] UUID
      # @return [ActiveMedusa::Relation]
      # @raise [RuntimeError] If no matching entity is found
      #
      def find(id)
        result = self.find_by_uuid(id)
        raise "Unable to find entity with ID #{id}" unless result
        result
      end

      ##
      # @param id [String]
      # @return [ActiveMedusa::Relation]
      #
      def find_by_id(id)
        self.where(Configuration.instance.solr_uuid_field => id).
            facet(false).first
      end

      ##
      # @param uri [String] Fedora resource URI
      # @return [ActiveMedusa::Relation]
      # @raise [SocketError] If the host is unknown
      #
      def find_by_uri(uri)
        ActiveMedusa::Base.load(uri)
      end

      ##
      # Alias of `find_by_id`.
      #
      # @param uuid [String]
      # @return [ActiveMedusa::Relation]
      #
      def find_by_uuid(uuid)
        self.find_by_id(uuid)
      end

      def method_missing(name, *args, &block)
        name_s = name.to_s
        # handle Relation-like calls
        if [:count, :first, :limit, :order, :start, :where].include?(name.to_sym)
          return Relation.new(self).send(name, *args, &block)
        elsif name_s.start_with?('find_by_')
          # handle find_by_x calls
          prop = self.properties.select{ |p| p.class == self and
              p.name.to_s == name_s.gsub(/find_by_/, '') }.first
          if prop
            return self.where(prop.solr_field => args[0]).facet(false).first
          end
        end
        super
      end

      ##
      # @return [ActiveMedusa::Relation] An empty Relation.
      #
      def none
        Relation.new
      end

      def respond_to_missing?(method_name, include_private = false)
        method_name_s = method_name.to_s
        if %w(count first limit order start where).include?(method_name_s)
          return true
        elsif method_name_s.start_with?('find_by_') and
            self.properties.select{ |p| p.class == self and
                p.name.to_s == method_name_s.gsub(/find_by_/, '') }.any?
          return true
        end
        super
      end

    end

  end

end
