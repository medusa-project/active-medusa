require_relative 'test_helper'

class TransactionsTest < Minitest::Test

  class Foo
    include ActiveMedusa::Transactions
    attr_accessor :transaction_url
  end

  def setup
    @f4_url = ActiveMedusa::Configuration.instance.fedora_url.chomp('/')
    @obj = Foo.new
    @obj.transaction_url = @f4_url + '/tx:23942034982340'
    @non_tx_url = @f4_url + '/bla/bla/bla'
    @tx_url = @obj.transaction_url + '/bla/bla/bla'
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
