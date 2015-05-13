require 'active_medusa/configuration'
require 'rsolr'

module ActiveMedusa

  class Solr

    @@client = nil

    ##
    # @return [RSolr]
    #
    def self.client
      @@client = RSolr.connect(
          url: Configuration.instance.solr_url.chomp('/') + '/' +
              Configuration.instance.solr_core) unless @@client
      @@client
    end

    ##
    # Gets the Solr-compatible field name for a given predicate.
    #
    # @param predicate [String]
    #
    def self.field_name_for_predicate(predicate) # TODO: use it or lose it
      # convert all non-alphanumerics to underscores and then replace
      # repeating underscores with a single underscore
      'uri_' + predicate.to_s.gsub(/[^0-9a-z ]/i, '_').gsub(/\_+/, '_') + '_txt'
    end

  end

end
