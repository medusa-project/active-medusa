require_relative 'test_helper'

class AssociationTest < Minitest::Test

  def test_initialize_accepts_params_hash
    a = ActiveMedusa::Association.new(name: 'cats')
    assert_equal 'cats', a.name
  end

end
