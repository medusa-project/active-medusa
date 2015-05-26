ActiveMedusa provides a simple ActiveRecord-like interface to a Fedora 4
repository, using Solr for lookup and querying. It relies on a strategy like
[fcrepo-message-consumer](https://github.com/fcrepo4/fcrepo-message-consumer)
or [fcrepo-camel](https://github.com/fcrepo4/fcrepo-camel) to synchronize Solr
with your repository, and never writes to Solr itself. This means you need to
either maintain an
[https://wiki.duraspace.org/display/FEDORA41/Indexing+Transformations](indexing
transformation) or configure fcrepo-camel to route to some other endpoint that
handles indexing. (See the
[https://wiki.duraspace.org/display/FEDORA41/External+Search](External Search)
and
[https://wiki.duraspace.org/display/FEDORA41/Setup+Camel+Message+Integrations]
(Setup Camel Message Integrations) sections of the Fedora wiki for more
information.)

# Features

* Basic and somewhat customizable RDF ontology. Create your own RDF predicates
  or use existing ones.
* Customizable Solr schema. Although some extra fields are required, their
  names are up to you, and you can use dynamic fields if you want.
* Supports both binary and container nodes.
* Supports "belongs-to" and "has-many" relationships between entities.
* No-configuration support for node hierarchy traversal.
* Relatively simple and lightweight.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active-medusa'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install active-medusa

# Usage

## Initializing

ActiveMedusa needs to know some stuff about your setup. Tell it like this:

    ActiveMedusa::Configuration.new do |config|
      config.fedora_url = 'http://localhost:8080/fcrepo/rest'
      config.logger = Rails.logger
      config.class_predicate = 'http://example.org/hasClass'
      config.solr_url = 'http://localhost:8983/solr'
      config.solr_core = 'collection1'
      config.solr_id_field = :id
      config.solr_parent_id_field = :parent_id
      config.solr_class_field = :class # used by ActiveMedusa finder methods
      config.solr_uuid_field = :uuid
      config.solr_default_search_field = :searchall
      config.solr_facet_fields = [:collection_facet, :creator_facet,
                                  :date_facet, :format_facet, :language_facet]
    end

(If you are using Rails, you would put this in
`config/initializers/active_medusa.rb`, and then restart your application.)

## Defining Entities

Let's declare some entity ("model") classes. `Collection` and `Item` will
correspond to Fedora 4 container nodes, and `Bytestream` will correspond to
Fedora binary nodes. These are all common entities found in many repositories,
but you could easily change the terminology to `Series` instead of `Collection`,
and so on.

    # collection.rb
    class Collection < ActiveMedusa::Base
      entity_class_uri 'http://example.org/Collection'
      has_many :items, predicate: 'http://example.org/contains'
      rdf_property :title,
                   xs_type: :string,
                   predicate: 'http://purl.org/dc/elements/1.1/title',
                   solr_field: 'title_s'
    end

    # item.rb
    class Item < ActiveMedusa::Base
      entity_class_uri 'http://example.org/Item'
      has_many :bytestreams, predicate: 'http://example.org/hasBytestream'
      has_many :items, predicate: 'http://example.org/hasChild'
      belongs_to :collection, solr_field: 'collection_s'
      belongs_to :item, solr_field: 'parent_s', name: 'parent'
      rdf_property :full_text,
                   xs_type: :string,
                   predicate: 'http://example.org/fullText',
                   solr_field: 'full_text_txt'
    end
    
    # bytestream.rb
    class Bytestream < ActiveMedusa::Base
      entity_class_uri 'http://example.org/Bytestream'
      belongs_to :item, predicate: 'http://example.org/isOwnedBy'
    end

### Defining Classes

Every entity needs to have a URI designating its class. This can be specified
with the `entity_class_uri` method. The value you define will be used as the
object of a triple whose predicate is
`ActiveMedusa::Configuration.class_predicate`.

### Defining Properties

`rdf_property` is a convenience method that maps entity properties to an
instance's RDF graph and creates accessor and finder methods for them.

`rdf_property` predicates must be unique and can only be used in one triple per
entity instance.

You do not need to define all, or any, of an entity's properties with
`rdf_property`. If you prefer, you can manually mutate an instance's
`RDF::Graph` instance, accessible via `rdf_graph`. But it is useful to define
at least the properties that you want to be searchable, because they will
receive `find_by_x` methods (see "Loading Entities").

### Defining Relationships

Using the `has_many` and `belongs_to` methods, the example above specifies
that collections can contain zero or more items; items can contain zero or more
bytestreams; and items can also contain zero or more items (as in aggregations,
a.k.a. compound objects). Note that both sides of the relationship must be
specified, so for every `has_many` on an owning entity, there must be a
`belongs_to` on the owned entity.

## Creating Entities

TODO: creating entities as children of other entities (but once created, can't
be moved)

`Item.new` will create an `Item` object, but it will not be saved to the
repository until `save` is called on it.

Before it can be saved, however, you must specify where in the Fedora node
hierarchy you want it to reside. You can do that by setting its `container_url`
property:

    item = Item.new(container_url: 'http://url/of/parent/container')
    item.save!

`Item.create` will create and save an object immediately.

Both of these methods accept a hash of properties as an argument.

Bang versions (!) of `create` and `save` are available that will raise errors
if anything goes wrong.

### Requesting a Slug

You can request that your new entity be given a particular slug in the
repository before you save it:

    item = Item.new
    item.requested_slug = 'kumquats'
    item.save!
    
There is no guarantee, however, that the entity will actually receive this slug,
and no error will be raised if it doesn't.

## Updating Entities

Simply call `update` an an entity. (Bang version [!] also available.)

## Deleting Entities

Call `delete` on an entity. This method accepts an optional boolean
`also_tombstone` parameter that will delete its tombstone as well.

## Loading Entities

*Note: Newly created entities cannot be loaded until the Solr index has been
committed. ActiveMedusa will not commit it automatically.*

To load an item by some property, you can use one of the finder methods, like
`find`, which will find by repository UUID:

    item = Item.find('some UUID')

If `find` finds multiple entities, it will return only one. This is the only
finder method that will raise an error if nothing is found.

Alternatively, you can find by repository URI:

    item = Item.find_by_uri('http://localhost:8080/fcrepo/rest/kumquats')

Then, there are the `find_by_x` methods, where `x` corresponds to some
property name:

    item = Item.find_by_title('2003 Global Outlook for 6-Quart Slow-Cookers')

Once an entity has been loaded, it can be reloaded:

    item.reload!

### Reading & Writing Metadata

The item's complete RDF graph is available by calling `rdf_graph` on any entity
instance. This returns an `RDF::Graph` instance which you can read:

    item.rdf_graph.each_statement do |st|
      if st.predicate.to_s == 'http://purl.org/dc/elements/1.1/title'
        puts 'Title is: ' + st.object.to_s
      end
    end

As well as write to:

    item.rdf_graph << RDF::Statement.new(nil,
        RDF::URI(http://purl.org/dc/elements/1.1/title),
        'Epistemology of the Kumquat')

Of course, you would need to call `item.save` to persist this change.

### Other Useful Entity Methods

* `id`/`uuid` (returns the node's UUID)
* `created_at` (returns the RDF object of `fedora:created` as a `Time` object)
* `updated_at` (returns the RDF object of `fedora:lastModified` as a `Time`
  object)
* `repository_url` (returns the node's repository URI/URL)
* `solr_representation` (returns the representation of the entity in Solr as a
  hash)
* `destroyed?`
* `persisted?`

## Node Hierarchy Traversal

The `children` method will allow you to enumerate a container's LDP children:

    collection = Collection.find('..')
    collection.children.each do |child|
      ..
    end

Likewise, a child can get its parent:

    parent = child.parent
    puts parent.class

## Binary Nodes

TODO: write this

You can attach binary nodes to any container as child nodes.

## Searching For Entities

*Note 1: Newly added entities will not appear in search results until the Solr
index has been committed. ActiveMedusa will not commit it automatically.*

*Note 2: Newly created entities will not appear in search results in the
same thread unless enough time has elapsed for Solr to have received them,
which is rarely the case. An easy and ugly way of getting around this is to
`sleep` for a bit after saving an entity to wait for it to catch up - hoping
that it does in time. But it's best to simply not try to do it.*

    items = Item.all.where(some_property: 'cats').
        where('arbitrary Solr query')

Items are loaded when `to_a` is called, explicitly or implicitly, as by `each`.

### Ordering

By default, results are sorted by relevance. To override this, use `order`
to sort by any sortable Solr field:

    Item.all.order('some_solr_field' => :asc)
    Item.all.order('some_solr_field') # same effect as above
    Item.all.order('some_solr_field' => :desc)
    Item.all.order('some_solr_field desc')

If no sort order is provided (via `order`), results will be sorted by relevance.

### Counts

    items = Item.all
    puts items.count # shortcut for items.to_a.total_length

### Start/Limit

    items = Item.all
    puts items.start(20).limit(20)

### Faceting

You can add facet queries:

    Item.all.facet('creator:Napoleon%20Bonaparte')
    Item.all.facet(['type:Book', 'subject:Citrus'])

To access returned facets, you might do something like:

    items = Item.where('..')
    # facet_fields returns an array of ActiveMedusa::Facet objects.
    items.facet_fields.each do |facet|
      # A Facet may have one or more ActiveMedusa::Facet::Term objects.
      facet.terms.each do |term|
        puts term.count
        puts term.label
        puts term.name
      end
    end

### Relevance

If no sort order is provided (via `order`), results will be sorted by relevance.
A relevance score can be accessed via the transient `score` property of any
retrieved entity.

### "More Like This"

If you have the [https://wiki.apache.org/solr/MoreLikeThisHandler]
(MoreLikeThisHandler) enabled in Solr, you can query by similarity:

    item = Item.find(id).more_like_this.limit(5)

### Transactions

You can query within a transaction using the `use_transaction_url` method of
`ActiveMedusa::Relation`.

    Item.all.use_transaction_url(url).where('..')

TODO: transactions with create, save, update, delete

## Validation

`ActiveMedusa::Base` includes `ActiveModel::Model`, which supplies all the
validation functionality that ActiveRecord enjoys. So, you can use
ActiveRecord validation methods on your ActiveMedusa entities.

## Forms

Because `ActiveMedusa::Base` includes `ActiveModel::Model`, your ActiveMedusa
entities should work perfectly well with Rails' FormHelper. (Other form
frameworks are untested.)

## Callbacks

Your entities can use the following `ActiveModel::Model` callbacks:

* `before_create`
* `before_delete`
* `before_load`
* `before_save`
* `before_update`
* `after_create`
* `after_delete`
* `after_load`
* `after_save`
* `after_update`

Example:

    class Item < ActiveMedusa::Base
      before_save :do_something
      
      def do_something
      end
    end

# Development

After checking out the repo, run `bin/setup` to install dependencies. Then,
run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then
run `bundle exec rake release` to create a git tag for the version, push git
commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Debugging

`ActiveMedusa::Relation` has `solr_request` and `solr_response` methods that
can help in tracking down issues with Solr. Use it like this:

    items = Item.all
    items.to_a # executes a Solr request
    puts items.solr_request
    puts items.solr_response

# Contributing

1. Fork it (https://github.com/[my-github-username]/active-medusa/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
