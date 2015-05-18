require 'active_medusa/configuration'
require 'active_medusa/relation'

module ActiveMedusa

  ##
  # Defines finder methods on [Base].
  #
  module Querying

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
    #
    def find(id, transaction_url = nil)
      self.find_by_uuid(id, transaction_url)
    end

    ##
    # @param uri [String] Fedora resource URI
    # @param transaction_url [String]
    # @return [ActiveMedusa::Relation]
    #
    def find_by_uri(uri, transaction_url = nil)
      self.where(id: "\"#{uri}\"").use_transaction_url(transaction_url).first
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
      if [:count, :first, :limit, :order, :start, :where].include?(name.to_sym)
        Relation.new(self).send(name, *args, &block)
      end
    end

    ##
    # @return [ActiveMedusa::Relation] An empty Relation.
    #
    def none
      Relation.new
    end

    def respond_to_missing?(method_name, include_private = false)
      [:count, :first, :limit, :order, :start, :where].
          include?(method_name.to_sym)
    end

  end

end
