module ActiveMedusa

  class Property

    # @!attribute class
    #   @return [Class] The class of the property's owning instance.
    attr_accessor :class

    # @!attribute name
    #   @return [String] The name of the property.
    attr_accessor :name

    # @!attribute rdf_predicate
    #   @return [String] The RDF predicate to use to store the property in
    #   Fedora.
    attr_accessor :rdf_predicate

    # @!attribute solr_field
    #   @return [String, Symbol] The Solr field in which the value of the
    #   property is stored.
    attr_accessor :solr_field

    # @!attribute type
    #   @return The XML Schema type of the property.
    attr_accessor :type

    ##
    # @param params [Hash]
    #
    def initialize(params = {})
      params.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=") }
    end

  end

end
