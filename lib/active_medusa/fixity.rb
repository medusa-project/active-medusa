module ActiveMedusa

  ##
  # Encapsulates a repository fixity result.
  #
  class Fixity

    # @!attribute content_location
    #   @return [String] The URI of the content as managed by the repository.
    attr_accessor :content_location

    # @!attribute repository_url
    #   @return [String] The URI of the fixity in the repository.
    attr_accessor :repository_url

    def self.from_graph(graph)
      fixity = Fixity.new
      graph.each_statement do |st|
        if st.predicate.to_s == 'http://www.loc.gov/premis/rdf/v1#hasFixity'
          fixity.repository_url = st.object.to_s
        end
        if st.predicate.to_s == 'http://www.loc.gov/premis/rdf/v1#hasContentLocationValue'
          fixity.content_location = st.object.to_s
        end
      end
      fixity
    end

  end

end
