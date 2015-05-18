require_relative 'test_helper'

class FedoraTest < Minitest::Test

  def test_client
    client = ActiveMedusa::Fedora.client
    assert_instance_of HTTPClient, client
  end

end
