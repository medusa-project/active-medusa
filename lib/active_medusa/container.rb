require 'active_medusa/base'
require 'active_model/validations'

module ActiveMedusa

  ##
  # Abstract class from which all ActiveMedusa container entities should
  # inherit.
  #
  class Container < Base

    ##
    # @return [ActiveMedusa::Relation]
    #
    def more_like_this
      ActiveMedusa::Relation.new(self).more_like_this
    end

    def repository_metadata_url
      self.repository_url ?
          transactional_url(self.repository_url).chomp('/') : nil
    end

    protected

    ##
    # Creates a new node by POSTing `parent_url`, and then populates the
    # instance's `rdf_graph` with a GET to its `repository_url`.
    #
    # @raise [RuntimeError]
    # @raise [ActiveMedusa::RecordInvalid]
    #
    def save_new
      run_callbacks :create do
        populate_outgoing_graph(self.rdf_graph)
        run_callbacks :validation do
          raise ActiveMedusa::RecordInvalid unless self.valid?
        end
        url = transactional_url(self.parent_url)
        body = self.rdf_graph.to_ttl
        headers = { 'Content-Type' => 'text/turtle' }
        headers['Slug'] = self.requested_slug if self.requested_slug.present?
        begin
          response = Fedora.client.post(url, body, headers)
        rescue HTTPClient::BadResponseError => e
          RepositoryError.from_bad_response_error(e)
        else
          self.repository_url = nontransactional_url(
              response.header['Location'].first)
          self.requested_slug = nil
          @persisted = true
          self.reload!
        end
      end
    end

  end

end
