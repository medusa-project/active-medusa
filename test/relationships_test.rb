require_relative 'test_helper'

class RelationshipsTest < Minitest::Test
=begin
  # Any entities created in the tests should use one of these slugs, to ensure
  # that they get torn down.
  SLUGS = %w(item1 item2 item3 item4 item5 item6 item7 item8 item9 item10)

  def setup
    @config = ActiveMedusa::Configuration.instance
    @http = HTTPClient.new
  end

  def teardown
    SLUGS.each do |slug|
      @http.delete("#{@config.fedora_url}/#{slug}") rescue nil
      @http.delete("#{@config.fedora_url}/#{slug}/fcr:tombstone") rescue nil
    end
  end
=end

  # associations

  def test_associations
    assert_equal 6, Item.associations.length
  end

  # belongs_to

  def test_belongs_to_requires_certain_options
    assert_raises RuntimeError do
      Item::belongs_to :something, invalid: 'bla', invalid2: 'bla'
    end
  end

  # children

  def test_children
    # TODO: write this
  end

  # parent

  def test_parent
    # TODO: write this
  end

end
