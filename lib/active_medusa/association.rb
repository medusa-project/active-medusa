module ActiveMedusa

  class Association

    class Type
      BELONGS_TO = :belongs_to
      HAS_MANY = :has_many
    end

    attr_accessor :name
    attr_accessor :rdf_predicate
    attr_accessor :solr_field
    attr_accessor :source_class
    attr_accessor :target_class
    attr_accessor :type

    ##
    # @param params [Hash]
    #
    def initialize(params = {})
      params.except(:id, :uuid).each do |k, v|
        send("#{k}=", v) if respond_to?("#{k}=")
      end
    end

  end

end
