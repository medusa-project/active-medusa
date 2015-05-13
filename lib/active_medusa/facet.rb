module ActiveMedusa

  class Facet

    class Term

      attr_accessor :count
      attr_accessor :facet
      attr_accessor :label
      attr_accessor :name

      def initialize
        @count = 0
      end

      def facet_query
        "#{self.facet.field}:\"#{self.name}\""
      end

    end

    attr_accessor :field
    attr_reader :terms

    def initialize
      @terms = []
    end

  end

end
