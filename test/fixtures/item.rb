class Item < ActiveMedusa::Container

  include ActiveMedusa::Indexable

  entity_class_uri 'http://example.org/Item'

  belongs_to :collection, rdf_predicate: 'http://example.org/isMemberOf',
             solr_field: :collection_s
  belongs_to :item, rdf_predicate: 'http://example.org/isChildOf',
             solr_field: :parent_uri_s, name: :parent_item
  has_many :bytestreams, rdf_predicate: 'http://example.org/hasBytestream'
  has_many :items

  property :full_text,
           type: :string,
           rdf_predicate: 'http://example.org/fullText',
           solr_field: 'full_text_txt'
  property :page_index,
           type: :int,
           rdf_predicate: 'http://example.org/pageIndex',
           solr_field: 'page_index_i'
  property :published,
           type: :boolean,
           rdf_predicate: 'http://example.org/isPublished',
           solr_field: 'published_b'

  before_create :do_before_create
  after_create :do_after_create
  before_destroy :do_before_destroy
  after_destroy :do_after_destroy
  before_load :do_before_load
  after_load :do_after_load
  before_save :do_before_save
  after_save :do_after_save
  before_update :do_before_update
  after_update :do_after_update

  def do_before_create
    @before_create_called = true
  end

  def do_after_create
    @after_create_called = true
  end

  def do_before_destroy
    @before_destroy_called = true
  end

  def do_after_destroy
    # can't set an ivar here because the instance will be frozen
  end

  def do_before_load
    @before_load_called = true
  end

  def do_after_load
    @after_load_called = true
  end

  def do_before_save
    @before_save_called = true
  end

  def do_after_save
    @after_save_called = true
  end

  def do_before_update
    @before_update_called = true
  end

  def do_after_update
    @after_update_called = true
  end
end
