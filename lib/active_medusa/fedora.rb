require 'httpclient'

module ActiveMedusa

  class Fedora

    @@http_client = nil

    # Assume that predicate URIs that start with any of these are
    # repository-managed. This may not be a safe assumption, but it works for
    # us for now.
    MANAGED_PREDICATES = [
        'http://fedora.info/definitions/',
        'http://www.jcp.org/jcr',
        'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
        'http://www.w3.org/2000/01/rdf-schema#',
        'http://www.w3.org/ns/ldp#'
    ]

    ##
    # @return [HTTPClient]
    #
    def self.client
      @@http_client = HTTPClient.new unless @@http_client
      @@http_client
    end

  end

end
