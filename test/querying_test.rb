require_relative 'test_helper'

class QueryingTest < Minitest::Test

  class Queryable < ActiveMedusa::Base
    rdf_property :color,
                 xs_type: :string,
                 predicate: 'http://example.org/color',
                 solr_field: 'color_s'
  end

  def setup
    @obj = Queryable.new
  end

  def test_all
    assert_instance_of ActiveMedusa::Relation, Queryable.all
  end

  def test_find
    #assert_instance_of ActiveMedusa::Relation, Queryable.find('valid uuid') # TODO: write this
    assert_nil Queryable.find('nonexistent uuid')
  end

  def test_find_by_uri
    #assert_instance_of Queryable, Queryable.find_by_uri('valid uri') # TODO: write this
    assert_nil Queryable.find_by_uri('http://nonexistent')
  end

  def test_find_by_uuid
    #assert_instance_of Queryable, Queryable.find_by_uuid('valid uuid') # TODO: write this
    assert_nil Queryable.find_by_uuid('nonexistent uuid')
  end

  def test_find_by_rdf_property
    #assert_instance_of ActiveMedusa::Relation, Queryable.find_by_color('red') # TODO: write this
    assert_nil Queryable.find_by_color('nonexistent color')
  end

  def test_method_forwarding
    assert_equal 0, Queryable.count
    assert_nil Queryable.first
    assert_instance_of ActiveMedusa::Relation, Queryable.limit(1)
    assert_instance_of ActiveMedusa::Relation, Queryable.order(:title)
    assert_instance_of ActiveMedusa::Relation, Queryable.start(0)
    assert_instance_of ActiveMedusa::Relation, Queryable.where(cats: 'dogs')
  end

  def test_none
    assert_instance_of ActiveMedusa::Relation, Queryable.none
  end

end
