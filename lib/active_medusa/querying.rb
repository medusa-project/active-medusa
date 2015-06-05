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
      # @param transaction_url [String]
      # @return [ActiveMedusa::Relation]
      # @raise [RuntimeError] If no matching entity is found
      #
      def find(id, transaction_url = nil)
        result = self.find_by_uuid(id, transaction_url)
        raise "Unable to find entity with ID #{id}" unless result
        result
      end

      ##
      # @param uri [String] Fedora resource URI
      # @param transaction_url [String]
      # @return [ActiveMedusa::Relation]
      #
      def find_by_uri(uri, transaction_url = nil)
        self.where(Configuration.instance.solr_uri_field => uri).
            use_transaction_url(transaction_url).first # TODO: don't need to do this through solr
      end

      ##
      # @param uuid [String]
      # @param transaction_url [String]
      # @return [ActiveMedusa::Relation]
      #
      def find_by_uuid(uuid, transaction_url = nil)
        self.where(Configuration.instance.solr_uuid_field => uuid).
            use_transaction_url(transaction_url).first
      end

      def method_missing(name, *args, &block)
        name_s = name.to_s
        # handle Relation-like calls
        if [:count, :first, :limit, :order, :start, :where].include?(name.to_sym)
          return Relation.new(self).send(name, *args, &block)
        elsif name_s.start_with?('find_by_')
          # handle find_by_x calls
          prop = self.rdf_properties.
              select{ |p| p[:class] == self and
                p[:name].to_s == name_s.gsub(/find_by_/, '') }.first
          if prop
            return self.where(prop[:solr_field] => args[0]).
                use_transaction_url(args[1]).first
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
            self.rdf_properties.select{ |p| p[:class] == self and
                p[:name].to_s == method_name_s.gsub(/find_by_/, '') }.any?
          return true
        end
        super
      end

    end

  end

end
