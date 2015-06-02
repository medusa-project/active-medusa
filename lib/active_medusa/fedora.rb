require 'httpclient'

module ActiveMedusa

  class Fedora

    @@http_client = nil

    ##
    # @return [HTTPClient]
    #
    def self.client
      @@http_client = HTTPClient.new unless @@http_client
      @@http_client
    end

  end

end
