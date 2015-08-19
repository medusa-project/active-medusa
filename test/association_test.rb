require_relative 'test_helper'

class AssociationTest < Minitest::Test

  def test_initialize_accepts_params_hash
    props = {
        name: 'cats',
        rdf_predicate: 'http://example.org/cats',
        solr_field: 'cats_s',
        source_class: Array,
        target_class: Hash,
        type: :string
    }
    a = ActiveMedusa::Association.new(props)
    props.each { |k, v| assert_equal v, a.send(k) }
  end

end
