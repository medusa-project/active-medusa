module ActiveMedusa

  class Association

    class Type
      BELONGS_TO = :belongs_to
      HAS_MANY = :has_many
    end

    # @!attribute cascade_deletes
    #   @return [Boolean] Applicable only to has-many associations.
    attr_accessor :cascade_deletes

    # @!attribute name
    #   @return [String] The name of the association's accessor on the source
    #   (declaring) side.
    attr_accessor :name

    # @!attribute rdf_predicate
    #   @return [String] The RDF predicate to use to store the association in
    #   Fedora.
    attr_accessor :rdf_predicate

    # @!attribute solr_field
    #   @return [String, Symbol] The Solr field in which the value of the
    #   `rdf_predicate` triple is stored.
    attr_accessor :solr_field

    # @!attribute source_class
    #   @return [Class] The class of the source (declaring) side of the
    #   association.
    attr_accessor :source_class

    # @!attribute target_class
    #   @return [Class] The class of the target side of the association.
    attr_accessor :target_class

    # @!attribute type
    #   @return [ActiveMedusa::Association::Type]
    attr_accessor :type

    ##
    # @param params [Hash]
    #
    def initialize(params = {})
      params.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=") }
    end

  end

end
