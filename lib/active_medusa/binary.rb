require 'active_medusa/base'

module ActiveMedusa

  ##
  # Abstract class from which all ActiveMedusa binary entities should inherit.
  #
  class Binary < Base

    # @!attribute external_resource_url
    #   @return [String]
    attr_accessor :external_resource_url

    # @!attribute media_type Should accompany `upload_pathname`. Will be
    # ignored if `external_resource_url` is set instead.
    #   @return [String]
    attr_accessor :media_type

    # @!attribute upload_pathname
    #   @return [String]
    attr_accessor :upload_pathname

    ##
    # @param params [Hash]
    #
    def initialize(params = {})
      @rdf_graph = new_rdf_graph
      super
    end

    def repository_metadata_url
      "#{transactional_url(self.repository_url).chomp('/')}/fcr:metadata"
    end

    protected

    ##
    # Creates a new node.
    #
    # @raise [RuntimeError]
    #
    def save_new
      run_callbacks :create do
        raise 'Validation error' unless self.valid?
        begin
          response = nil
          if self.upload_pathname
            File.open(self.upload_pathname) do |file|
              filename = File.basename(self.upload_pathname)
              headers = {
                  'Content-Disposition' => "attachment; filename=\"#{filename}\""
              }
              headers['Content-Type'] = self.media_type if
                  self.media_type.present?
              headers['Slug'] = self.requested_slug if
                  self.requested_slug.present?
              url = transactional_url(self.parent_url)
              response = Fedora.client.post(url, file, headers)
            end
          elsif self.external_resource_url
            url = transactional_url(self.parent_url)
            headers = { 'Content-Type' => 'text/plain' }
            headers['Slug'] = self.requested_slug if
                self.requested_slug.present?
            response = Fedora.client.post(url, nil, headers)
            headers = { 'Content-Type' => "message/external-body; "\
            "access-type=URL; URL=\"#{self.external_resource_url}\"" }
            Fedora.client.put(response.header['Location'].first, nil, headers)
          else
            raise 'Unable to save binary: both upload_pathname and '\
            'external_resource_url are nil.'
          end
          self.repository_url = nontransactional_url(
              response.header['Location'].first)
          @persisted = true
          # save metadata
          save_existing
        rescue HTTPClient::BadResponseError => e
          raise "#{e.res.status}: #{e.res.body}"
        end
      end
    end

    private

    ##
    # @return [RDF::Graph]
    #
    def new_rdf_graph
      graph = RDF::Graph.new
      graph << RDF::Statement.new(
          RDF::URI(), RDF::URI(Configuration.instance.class_predicate),
          RDF::URI(self.class.entity_class_uri))
      graph
    end

  end

end
