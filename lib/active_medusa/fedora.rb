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

    def self.log_request(method, url, headers = {}, body = nil)
      logger = Configuration.instance.logger
      logger.info("#{ActiveMedusa::LOG_PREFIX} Fedora request: "\
      "#{method.to_s.upcase} #{url}")
      logger.debug("#{ActiveMedusa::LOG_PREFIX} "\
      "Fedora request headers:\n#{headers.map{ |k, v| "#{k}: #{v}" }.join("\n")}")
      logger.debug("#{ActiveMedusa::LOG_PREFIX} "\
      "Fedora request body:\n#{body}") if body.kind_of?(String)
    end

    def self.log_response(status_code, status_line, headers, body = nil)
      logger = Configuration.instance.logger
      logger.info("#{ActiveMedusa::LOG_PREFIX} Fedora response status: "\
      "#{status_code} #{status_line}")
      logger.debug("#{ActiveMedusa::LOG_PREFIX} "\
      "Fedora response headers:\n#{headers.map{ |k, v| "#{k}: #{v}" }.join("\n")}")
      logger.debug("#{ActiveMedusa::LOG_PREFIX} "\
      "Fedora response body:\n#{body}") if body.kind_of?(String)
    end

    def self.request(method, url, body, headers)
      log_request(method, url, headers, body)
      begin
        response = client.send(method, url, body, headers)
        log_response(response.status, response.reason,
                            response.header.all, response.body)
      rescue HTTPClient::BadResponseError => e
        raise RepositoryError.from_bad_response_error(e)
      else
        return response
      end
    end

  end

end
