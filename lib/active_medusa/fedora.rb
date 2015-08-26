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

    def self.request(method, url, body, headers)
      logger = Configuration.instance.logger
      # log the request
      logger.info("#{method.to_s.upcase} #{url}")
      logger.debug("Request headers:\n#{headers.map{ |k, v| "#{k}: #{v}" }.join("\n")}")
      logger.debug("Request body:\n#{body.slice(0, 10000)}") if
          body.kind_of?(String)
      begin
        @@http_client = HTTPClient.new unless @@http_client
        response = @@http_client.send(method, url, body, headers)
        # log the response
        logger.info("#{response.status} #{response.reason}")
        logger.debug("Response headers:\n#{response.header.all.map{ |k, v| "#{k}: #{v}" }.join("\n")}")
        logger.debug("Response body:\n#{response.body.slice(0, 10000)}") if
            response.body.kind_of?(String)
      rescue HTTPClient::BadResponseError => e
        raise RepositoryError.from_bad_response_error(e)
      else
        return response
      end
    end

  end

end
