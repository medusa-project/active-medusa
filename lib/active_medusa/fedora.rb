require 'httpclient'

module ActiveMedusa

  class Fedora

    @@http_client = nil

    ##
    # Performs an HTTP DELETE request.
    #
    # @raise [ActiveMedusa::RepositoryError]
    #
    def self.delete(url, body = nil, headers = {})
      request(:delete, url, body, headers)
    end

    ##
    # Performs an HTTP GET request.
    #
    # @raise [ActiveMedusa::RepositoryError]
    #
    def self.get(url, body = nil, headers = {})
      request(:get, url, body, headers)
    end

    ##
    # Performs an HTTP POST request.
    #
    # @raise [ActiveMedusa::RepositoryError]
    #
    def self.post(url, body = nil, headers = {})
      request(:post, url, body, headers)
    end

    ##
    # Performs an HTTP PUT request.
    #
    # @raise [ActiveMedusa::RepositoryError]
    #
    def self.put(url, body = nil, headers = {})
      request(:put, url, body, headers)
    end

    private

    ##
    # @return [HTTPClient]
    #
    def self.client
      @@http_client = HTTPClient.new unless @@http_client
      @@http_client
    end

    def self.request(method, url, body, headers)
      begin
        client.send(method, url, body, headers)
      rescue HTTPClient::BadResponseError => e
        raise RepositoryError.from_bad_response_error(e)
      end
    end

  end

end
