module ActiveMedusa

  class RepositoryError < StandardError

    # @!attribute status_code
    #   @return [Integer] The HTTP response status code.
    attr_accessor :status_code

    # @!attribute status_line
    #   @return [String] The HTTP response status line.
    attr_accessor :status_line

    # @!attribute body
    #   @return [String] The HTTP response body.
    attr_accessor :body

    ##
    # @param error [HTTPClient::BadResponseError]
    # @return [ActiveMedusa::RepositoryError]
    #
    def self.from_bad_response_error(error)
      RepositoryError.new(
          status_code: error.res.code, status_line: error.res.reason,
          body: error.res.body)
    end

    ##
    # @param params [Hash]
    #
    def initialize(params = {})
      super
      params.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=") }
    end

  end

end
