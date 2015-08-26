require_relative 'test_helper'

class FedoraTest < Minitest::Test

  SLUG = 'cats'

  def setup
    @config = ActiveMedusa::Configuration.instance
  end

  def teardown
    ActiveMedusa::Fedora.
        delete(@config.fedora_url + '/' + SLUG) rescue nil
    ActiveMedusa::Fedora.
        delete(@config.fedora_url + '/' + SLUG + '/fcr:tombstone') rescue nil
  end

  def test_post_and_delete
    # create a new node
    response = ActiveMedusa::Fedora.post(@config.fedora_url, nil,
             { 'Slug' => SLUG })
    assert_equal 201, response.status

    # delete it
    url = response.header['Location'].first
    response = ActiveMedusa::Fedora.delete(url)
    assert_equal 204, response.status

    # assert that it has been deleted
    assert_raises ActiveMedusa::RepositoryError do
      response = ActiveMedusa::Fedora.get(url)
      assert_equal 410, response.status
    end
  end

  def test_get
    response = ActiveMedusa::Fedora.get(@config.fedora_url)
    assert_equal 200, response.status
  end

  def test_put
    response = ActiveMedusa::Fedora.put(@config.fedora_url + '/' + SLUG)
    assert_equal 201, response.status
  end

end
