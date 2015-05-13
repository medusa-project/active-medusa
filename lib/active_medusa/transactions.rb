module ActiveMedusa

  ##
  # See https://wiki.duraspace.org/display/FEDORA41/Transactions
  #
  module Transactions

    def self.included(mod)
      mod.extend ClassMethods
    end

    module ClassMethods

      ##
      # Creates a transaction.
      #
      # @returns [String] Transaction base URL
      #
      def create_transaction(http_client)
        repository_url = Configuration.instance.fedora_url.chomp('/')
        url = repository_url + '/fcr:tx'
        response = http_client.post(url)
        response.header['Location'].first
      end

      ##
      # Commits the transaction with the given ID.
      #
      # @param id [String]
      # @param http_client [HTTPClient]
      # @return [HTTPResponse]
      #
      def commit_transaction(id, http_client)
        http_client.post(id + '/fcr:tx/fcr:commit')
      end

      ##
      # Rolls back the transaction with the given ID.
      #
      # @param id [String]
      # @param http_client [HTTPClient]
      # @return [HTTPResponse]
      #
      def rollback_transaction(id, http_client)
        http_client.post(id + '/fcr:tx/fcr:rollback')
      end

    end

    ##
    # Converts the given URL into a non-transactional URL based on the current
    # value of `transaction_url`. If `transaction_url` is nil, returns the given
    # URL unchanged.
    #
    # @param url [String]
    # @return [String]
    #
    def nontransactional_url(url)
      if self.transaction_url
        return url.gsub(self.transaction_url.chomp('/'),
                        Configuration.instance.fedora_url.chomp('/'))
      end
      url
    end

    ##
    # Converts the given URL into a transactional URL based on the current
    # value of `transaction_url`. If `transaction_url` is nil, returns the given
    # URL unchanged.
    #
    # @param url [String]
    # @return [String]
    #
    def transactional_url(url)
      f4_url = Configuration.instance.fedora_url.chomp('/')
      if self.transaction_url and !url.start_with?(f4_url + '/tx:')
        return url.gsub(f4_url, self.transaction_url.chomp('/'))
      end
      url
    end

  end

end
