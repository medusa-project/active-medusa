require_relative 'test_helper'

class TransactionsTest < Minitest::Test

  # Any entities created in the tests should use one of these slugs, to ensure
  # that they get torn down.
  SLUGS = %w(node1 node2 node3 node4 node5 node6 node7 node8 node9 node10)

  class Foo
    include ActiveMedusa::Transactions
    attr_accessor :transaction_url
  end

  def setup
    @http = HTTPClient.new
    @config = ActiveMedusa::Configuration.instance
    @f4_url = @config.fedora_url.chomp('/')
    @obj = Foo.new
    @obj.transaction_url = @f4_url + '/tx:23942034982340'
    @non_tx_url = @f4_url + '/bla/bla/bla'
    @tx_url = @obj.transaction_url + '/bla/bla/bla'
  end

  def teardown
    SLUGS.each do |slug|
      @http.delete("#{@config.fedora_url}/#{slug}") rescue nil
      @http.delete("#{@config.fedora_url}/#{slug}/fcr:tombstone") rescue nil
    end
  end

  # transaction

  def test_transaction
    non_tx_url = "#{@config.fedora_url}/#{SLUGS[0]}"
    ActiveMedusa::Base.transaction do |tx_url|
      item = Item.create!(parent_url: @config.fedora_url,
                          requested_slug: SLUGS[0])
      assert_equal 200,
                   @http.get(item.transactional_url(item.repository_url)).status
    end
    assert_equal 200, @http.get(non_tx_url).status
  end

  def test_transaction_rolls_back_on_error
    # assert that an item created in a transaction does not exist outside the
    # transaction
    non_tx_url = "#{@config.fedora_url}/#{SLUGS[0]}"
    assert_raises RuntimeError do
      ActiveMedusa::Base.transaction do |tx_url|
        Item.create!(parent_url: @config.fedora_url, requested_slug: SLUGS[0],
                     transaction_url: tx_url)
        raise 'oops'
      end
    end
    assert_raises HTTPClient::BadResponseError do
      assert_equal 404, @http.get(non_tx_url).status
    end
  end

  def test_nontransactional_url_should_work_properly
    assert_equal @non_tx_url, @obj.nontransactional_url(@tx_url)
  end

  def test_transactional_url_should_work_properly
    assert_equal @tx_url, @obj.transactional_url(@non_tx_url)

    # don't transactionalize an already-transactional url
    assert_equal @tx_url, @obj.transactional_url(@tx_url)
  end

end
