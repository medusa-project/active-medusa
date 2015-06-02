require_relative 'test_helper'

class FedoraTest < Minitest::Test

  def test_client
    client = ActiveMedusa::Fedora.client
    assert_instance_of HTTPClient, client

    response = client.get(ActiveMedusa::Configuration.instance.fedora_url)
    assert_equal 200, response.status
  end

end
