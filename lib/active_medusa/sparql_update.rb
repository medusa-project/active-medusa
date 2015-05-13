module ActiveMedusa

  ##
  # Bare-bones class that assists in building SPARQL Update statements that
  # ActiveMedusa can use. It is not a general-purpose SPARQL Update class and
  # shouldn't be used outside of ActiveMedusa.
  #
  # This class uses the Builder pattern, so methods can be chained, like:
  #
  #     up = SPARQLUpdate.new
  #     up.prefix('..').delete('..').delete('..').insert('..')
  #
  # TODO: replace with ruby-rdf/sparql when it supports SPARQL update
  #
  class SPARQLUpdate

    def initialize
      @deletes = Set.new
      @inserts = Set.new
      @prefixes = Set.new
    end

    ##
    # Adds a statement into a DELETE WHERE clause.
    #
    # @param subject string nil will result in "<>"
    # @param predicate string
    # @param object string
    # @param quote_object boolean
    # @return self
    #
    def delete(subject, predicate, object, quote_object = true)
      object = quote_object ? "\"#{object.to_s.gsub('"', '\"')}\"" : object
      @deletes << { subject: subject, predicate: predicate, object: object }
      self
    end

    ##
    # Adds a statement into an INSERT clause.
    #
    # @param subject string nil will result in "<>"
    # @param predicate string
    # @param object string
    # @param quote_object boolean
    # @return self
    #
    def insert(subject, predicate, object, quote_object = true)
      object_s = object.to_s.strip
      if quote_object
        value = "\"#{object_s.gsub('"', '\"')}\""
        if object_s.lines.length > 1
          value = "\"\"#{value}\"\""
        end
      else
        value = object_s
      end
      @inserts << { subject: subject, predicate: predicate, object: value }
      self
    end

    ##
    # Declares a prefix.
    #
    # @param prefix string
    # @param uri string
    # @return self
    #
    def prefix(prefix, uri)
      @prefixes << { prefix: prefix, uri: uri } if prefix.present? and
          uri.present?
      self
    end

    def to_s
      s = ''
      @prefixes.each do |hash|
        s += "PREFIX #{hash[:prefix]}: <#{hash[:uri]}>\n"
      end

      @deletes.each do |del|
        subject = del[:subject].nil? ? '<>' : del[:subject]
        s += "DELETE WHERE { #{subject} #{del[:predicate]} #{del[:object]} };\n"
      end

      s += "INSERT {\n"
      inserts = @inserts.map do |ins|
        subject = ins[:subject].nil? ? '<>' : ins[:subject]
        "  #{subject} #{ins[:predicate]} #{ins[:object]}"
      end
      s += inserts.join(" .\n")
      s += " .\n}\nWHERE { }"
    end

  end

end
