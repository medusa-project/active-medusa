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

    ##
    # Returns the PREMIS byte size, populated by the repository. Not available
    # until the instance has been persisted.
    #
    # @return [Integer]
    #
    def byte_size
      self.rdf_graph.any_object('http://www.loc.gov/premis/rdf/v1#hasSize').to_i
    end

    def repository_metadata_url
      self.repository_url ?
          "#{transactional_url(self.repository_url).chomp('/')}/fcr:metadata" :
          nil
    end

    protected

    ##
    # Creates a new node by POSTing `parent_url`, and then populates the
    # instance's `rdf_graph` with a GET to its `fcr:metadata`.
    #
    # @raise [RuntimeError]
    # @raise [ActiveModel::ValidationError]
    #
    def save_new
      run_callbacks :create do
        raise ActiveModel::ValidationError unless self.valid?
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
        # if there are any triples in need of saving, copy them into the
        # canonical graph and re-save
        if self.rdf_graph.count > 0
          graph_dup = RDF::Graph.new
          self.rdf_graph.copy_into(graph_dup)
          self.reload!
          graph_dup.each_statement do |st|
            self.rdf_graph << st
          end
          save_existing
        else
          self.reload!
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
