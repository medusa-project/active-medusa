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
          info("Add Solr document: #{doc[Configuration.instance.solr_id_field]}")
      Configuration.instance.logger.debug("Add Solr document: #{doc}")
      client.add(doc)
    end

    def self.delete_by_id(id)
      Configuration.instance.logger.info("Delete Solr document: #{id}")
      client.delete_by_id(id)
    end

    def self.get(endpoint, options = {})
      Configuration.instance.logger.debug("Solr request: #{endpoint}; #{options}")
      client.get(endpoint, options)
    end

  end

end
