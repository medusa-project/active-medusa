require 'active_medusa/configuration'
require 'rsolr'

module ActiveMedusa

  class Solr

    @@client = nil

    ##
    # Returns the shared Solr client.
    #
    # @return [RSolr::Client]
    #
    def self.client
      @@client = RSolr.connect(
          url: Configuration.instance.solr_url.chomp('/') + '/' +
              Configuration.instance.solr_core) unless @@client
      @@client
    end

    def self.add(doc)
      Configuration.instance.logger.
          info("#{ActiveMedusa::LOG_PREFIX} Add Solr document: #{doc[Configuration.instance.solr_id_field]}")
      Configuration.instance.logger.
          debug("#{ActiveMedusa::LOG_PREFIX} Add Solr document: #{doc}")
      client.add(doc)
    end

    def self.delete_by_id(id)
      Configuration.instance.logger.
          info("#{ActiveMedusa::LOG_PREFIX} Delete Solr document: #{id}")
      client.delete_by_id(id)
    end

    def self.get(endpoint, options = {})
      Configuration.instance.logger.
          debug("#{ActiveMedusa::LOG_PREFIX} Solr request: #{endpoint}; #{options}")
      client.get(endpoint, options)
    end

  end

end
