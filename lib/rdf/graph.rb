module RDF

  ##
  # Reopen RDF::Graph to add some useful methods.
  #
  class Graph

    ##
    # Copies the statements from the instance into the given graph.
    #
    # @param graph [RDF::Graph]
    # @return [RDF::Graph] The input graph.
    #
    def copy_into(graph)
      self.each_statement do |st|
        graph << st.dup
      end
      graph
    end

    ##
    # Returns any object corresponding to the given predicate.
    #
    # @param predicate string or RDF::URI
    # @return string, RDF::URI, or nil
    #
    def any_object(predicate)
      self.each_statement do |statement|
        return statement.object if statement.predicate.to_s.end_with?(predicate)
      end
      nil
    end

    ##
    # @param predicate string or RDF::URI
    # @return RDF::Graph
    #
    def statements_with_predicate(predicate)
      out_graph = RDF::Graph.new
      self.each_statement do |statement|
        out_graph << statement if statement.predicate.to_s.end_with?(predicate)
      end
      out_graph
    end

  end

end