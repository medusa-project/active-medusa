require 'active_medusa/base'

module ActiveMedusa

  ##
  # Abstract class from which all ActiveMedusa binary entities should inherit.
  #
  class Binary < Base

    extend Gem::Deprecate

    # @!attribute external_resource_url
    #   @return [String]
    attr_accessor :external_resource_url

    # @!attribute media_type Should accompany `upload_pathname`. Will be
    # ignored if `external_resource_url` is set instead.
    #   @return [String]
    attr_accessor :media_type

    # @!attribute upload_filename
    #   @return [String] Overrides the filename sent to the repository in the
    #     `Content-Disposition` header during upload.
    attr_accessor :upload_filename

    # @!attribute upload_io
    #   @return [IO]
    attr_accessor :upload_io

    # @!attribute upload_pathname
    #   @return [String] The pathname of the file to upload; its actual filename
    #     will be sent to the repository in the `Content-Disposition` header
    #     unless `upload_filename` is set.
    #   @deprecated Use {#upload_io} instead
    attr_accessor :upload_pathname

    ##
    # Checks the fixity. Works only on persisted entities.
    #
    # @return [ActiveMedusa::Fixity, nil]
    #
    def fixity
      url = repository_fixity_url
      if url
        response = Fedora.client.get(url, nil,
                                     { 'Accept' => 'application/n-triples' })
        graph = RDF::Graph.new
        graph.from_ntriples(response.body)
        return Fixity.from_graph(graph)
      end
      nil
    end

    def repository_fixity_url
      self.repository_url ?
          "#{transactional_url(self.repository_url).chomp('/')}/fcr:fixity" :
          nil
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
    # @raise [ActiveMedusa::RecordInvalid]
    #
    def save_new
      run_callbacks :create do
        raise ActiveMedusa::RecordInvalid unless self.valid?
        response = nil
        if self.upload_pathname
          File.open(self.upload_pathname) do |file|
            filename = self.upload_filename ||
                File.basename(self.upload_pathname)
            headers = {
                'Content-Disposition' => "attachment; filename=\"#{filename}\""
            }
            headers['Content-Type'] = self.media_type if
                self.media_type.present?
            headers['Slug'] = self.requested_slug if
                self.requested_slug.present?
            url = transactional_url(self.parent_url)
            response = Fedora.post(url, file, headers)
          end
        elsif self.upload_io
          headers = {}
          headers['Content-Disposition'] =
              "attachment; filename=\"#{self.upload_filename}\"" if
              self.upload_filename
          headers['Content-Type'] = self.media_type if
              self.media_type.present?
          headers['Slug'] = self.requested_slug if
              self.requested_slug.present?
          url = transactional_url(self.parent_url)
          response = Fedora.post(url, upload_io, headers)
        elsif self.external_resource_url
          url = transactional_url(self.parent_url)
          headers = { 'Content-Type' => "message/external-body; "\
          "access-type=URL; URL=\"#{self.external_resource_url}\"" }
          headers['Slug'] = self.requested_slug if
              self.requested_slug.present?
          response = Fedora.post(url, nil, headers)
        else
          raise 'Unable to save binary: both upload_pathname and '\
          'external_resource_url are nil.'
        end

        self.repository_url = nontransactional_url(
            response.header['Location'].first)
        @persisted = true

        # copy any triples/properties in need of saving into the canonical
        # graph and re-save
        backup_graph = RDF::Graph.new
        self.rdf_graph.copy_into(backup_graph)

        backup_props = {}
        @@properties.select{ |p| p.class == self.class }.each do |prop|
          backup_props[prop.name] = send(prop.name)
        end

        self.reload!

        backup_props.each { |name, value| send("#{name}=", value) }
        backup_graph.each_statement { |st| self.rdf_graph << st }
        save_existing
      end
    end

  end

end
