module ActiveMedusa

  ##
  # Encapsulates a repository fixity result.
  #
  class Fixity

    class Status
      BAD_CHECKSUM = :BAD_CHECKSUM
      BAD_SIZE = :BAD_SIZE
      OK = :OK
    end

    # @!attribute content_location
    #   @return [String] The URI of the content as managed by the repository.
    attr_accessor :content_location

    # @!attribute digest
    #   @return [String] The correct digest.
    attr_accessor :digest

    # @!attribute repository_url
    #   @return [String] The URI of the fixity in the repository.
    attr_accessor :repository_url

    # @!attribute size
    #   @return [Integer] The correct size.
    attr_accessor :size

    # @!attribute statuses
    #   @return [Set<Symbol>] Set of Status constants.
    attr_reader :statuses

    def self.from_graph(graph)
      fixity = Fixity.new
      graph.each_statement do |st|
        if st.predicate.to_s == 'http://www.loc.gov/premis/rdf/v1#hasFixity'
          fixity.repository_url = st.object.to_s
        elsif st.predicate.to_s == 'http://www.loc.gov/premis/rdf/v1#hasContentLocationValue'
          fixity.content_location = st.object.to_s
        elsif st.predicate.to_s == 'http://fedora.info/definitions/v4/repository#status'
          fixity.statuses << st.object.to_s.to_sym
        elsif st.predicate.to_s == 'http://www.loc.gov/premis/rdf/v1#hasMessageDigest'
          fixity.digest = st.object.to_s
        elsif st.predicate.to_s == 'http://www.loc.gov/premis/rdf/v1#hasSize'
          fixity.size = st.object.to_s.to_i
        end
      end
      fixity.statuses << Status::OK if fixity.statuses.length == 0
      fixity
    end

    def initialize
      @statuses = Set.new
    end

  end

end
