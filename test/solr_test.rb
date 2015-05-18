require_relative 'test_helper'

class SolrTest < Minitest::Test

  def test_client
    client = ActiveMedusa::Solr.client
    assert_instance_of RSolr::Client, client
    assert_equal 0, client.get('select')['responseHeader']['status']
  end

end
