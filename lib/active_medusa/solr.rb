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

  end

end
