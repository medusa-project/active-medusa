# ActiveMedusa

ActiveMedusa provides a simple ActiveRecord-like interface to a Fedora 4
repository, using Solr for lookup and querying. It relies on a strategy like
[fcrepo-message-consumer](https://github.com/fcrepo4/fcrepo-message-consumer)
or [fcrepo-camel](https://github.com/fcrepo4/fcrepo-camel) to synchronize Solr
with your repository, and never writes to Solr itself. This means you need to
either maintain an [indexing transformation]
(https://wiki.duraspace.org/display/FEDORA41/Indexing+Transformations) or
configure fcrepo-camel to route to some other endpoint that handles indexing.
(See the [External Search]
(https://wiki.duraspace.org/display/FEDORA41/External+Search) and
[Setup Camel Message Integrations]
(https://wiki.duraspace.org/display/FEDORA41/Setup+Camel+Message+Integrations)
sections of the Fedora wiki for more information.)

# Features

* Basic and somewhat customizable RDF ontology. Create your own RDF predicates
  or use existing ones.
* Customizable Solr schema. Although some extra fields are required, their
  names are up to you.
* Supports binary and container nodes, both of which are first-class, queryable
  entities.
* Direct access and mutation of entities' RDF graphs.
* Supports "belongs-to" and "has-many" relationships between entities.
* No-configuration support for node hierarchy traversal via automatic `parent`
  and `children` methods on entities.

# Limitations

* No cascading
* No uniquing
* Can only set references on the owned side
* Probably a lot more

## Installation

Currently ActiveMedusa is not available via rubygems. There are a couple of
other options:

### Refer to a local copy

Check out the code from GitHub and point to it in your application's Gemfile:

```ruby
gem 'active-medusa', path: '/path/to/active_medusa'
```

### Refer to the copy on GitHub

Add this line to your application's Gemfile:

```ruby
gem 'active-medusa', github: 'medusa-project/active-medusa'
```

Then execute:

    $ bundle

Or install it yourself as:

    $ gem install active-medusa

# Usage

## Initializing

ActiveMedusa needs to know some stuff about your setup. Tell it like this:

```ruby
ActiveMedusa::Configuration.new do |config|
  config.fedora_url = 'http://localhost:8080/fcrepo/rest'
  config.logger = Rails.logger
  config.class_predicate = 'http://example.org/hasClass'
  config.solr_url = 'http://localhost:8983/solr'
  config.solr_core = 'collection1'
  config.solr_more_like_this_endpoint = '/mlt'
  config.solr_uri_field = :id
  config.solr_class_field = :class_s # used by ActiveMedusa finder methods
  config.solr_uuid_field = :uuid_s
  config.solr_default_search_field = :searchall_txt
  config.solr_facet_fields = [:collection_facet, :creator_facet,
                              :date_facet, :format_facet, :language_facet]
end
```

(If you are using Rails, you would put this in
`config/initializers/active_medusa.rb`, and then restart your application.)

### Configuring Fedora to populate Solr

Fedora needs to be configured to index its content in Solr. (See the
[External Search]
(https://wiki.duraspace.org/display/FEDORA41/External+Search) and [Setup Camel
Message Integrations]
(https://wiki.duraspace.org/display/FEDORA41/Setup+Camel+Message+Integrations)
sections of the Fedora wiki). Setting this up is beyond the scope of
ActiveMedusa; but keep in mind that any Solr fields referred to in your
`ActiveMedusa::Configuration` object, as well as any referred to in your
entities (see below), need to exist in Solr and be accounted for in your
indexing transformation. In the example above, `searchall_txt` is presumably a
dynamic `copyField` that the indexing transformation does not need to worry
about, and likewise the `*_facet` fields; but all of the rest need to exist,
either as regular or dynamic fields.

## Defining Entities

Let's declare some entity/model classes. `Collection` and `Item` will
correspond to Fedora container nodes, and `Bytestream` will correspond to
Fedora binary nodes. These are all common entities found in many repositories,
but you could change the nomenclature to `Series` instead of `Collection`,
and so on. Note that `Collection` and `Item` inherit from
`ActiveMedusa::Container` while `Bytestream` inherits from
`ActiveMedusa::Binary`. These are the two base classes from which all of your
entities must inherit.

```ruby
# collection.rb
class Collection < ActiveMedusa::Container
  entity_class_uri 'http://example.org/Collection'
  has_many :items
  rdf_property :title,
               xs_type: :string,
               predicate: 'http://purl.org/dc/elements/1.1/title',
               solr_field: 'title_s'
end

# item.rb
class Item < ActiveMedusa::Container
  entity_class_uri 'http://example.org/Item'
  has_many :items
  has_many :bytestreams
  belongs_to :collection, predicate: 'http://example.org/isMemberOf',
             solr_field: :collection_s
  belongs_to :item, predicate: 'http://example.org/isChildOf',
             solr_field: 'parent_s', name: 'parent'
  rdf_property :full_text,
               xs_type: :string,
               predicate: 'http://example.org/fullText',
               solr_field: 'full_text_txt'
end

# bytestream.rb
class Bytestream < ActiveMedusa::Binary
  entity_class_uri 'http://example.org/Bytestream'
  belongs_to :item, predicate: 'http://example.org/isOwnedBy'
end
```

### Defining Classes

Every entity needs to have a URI designating its class. This can be specified
with the `entity_class_uri` method. The value you define will be used as the
object of a triple whose predicate is the value of
`ActiveMedusa::Configuration.class_predicate`.

### Defining Properties

`rdf_property` is a convenience method that maps entity properties to an
instance's RDF graph and creates accessor and finder methods for them. It also
enables bonus features like validation, `find_by_x`, auto-generated accessors,
and ability to use the properties in `create` and `update` calls.

`rdf_property` predicates must be unique and can only be used in one triple per
entity graph.

You do not need to define all, or any, of an entity's properties with
`rdf_property`. If you prefer, you can manually mutate an instance's
`RDF::Graph` instance, accessible via `rdf_graph`. But in that case, you
wouldn't get the bonus features.

### Defining Relationships

Using the `has_many` and `belongs_to` methods, the example above specifies that
collections can contain zero or more items; items can contain zero or more
bytestreams; and items can also contain zero or more items (as in aggregations,
a.k.a. compound objects). Note that both sides of the relationship must be
specified, so for every `has_many` on an owning entity, there must be a
`belongs_to` on the owned entity. The `belongs_to` side also requires a
`:predicate` option that specifies what RDF predicate to use to store the
relationship in Fedora.

*Note: If any of your entity classes reside in a namespace, you will need to
add a `class_name` option to your relationship definitions:*

```ruby
# collection.rb
module Entities
  class Collection < ActiveMedusa::Container
    has_many :items, class_name: 'Entities::Item'
  end
end

# item.rb
module Entities
  class Item < ActiveMedusa::Container
    belongs_to :collection, predicate: 'http://example.org/isMemberOf',
               solr_field: :collection_s, class_name: 'Entities::Collection'
  end
end
```

## Creating Entities

`Item.new` will create an `Item` object, but it will not be saved to the
repository until `save` is called on it.

Before it can be saved, however, you must specify where in the Fedora node
hierarchy you want it to reside. You do that by setting its `parent_url`
property:

```ruby
item = Item.new(parent_url: 'http://url/of/parent/container')
item.save!
```

Or, if you are not sure of its parent's URL, but you have its parent:

```ruby
parent_item = Item.find(..)
new_item = Item.new(parent_url: parent_item.repository_url)
new_item.save!
```

`Item.create` will create and save an object immediately.

Both of these methods accept a hash of properties as an argument.

Bang versions (!) of `create` and `save` are available that will raise errors
if anything goes wrong.

Note that the constructor accepts any parameter defined in an `rdf_property`
statement, as well as any `belongs_to` relationship.

### Establishing Relationships

Establishing relationships between two new entities is easy:

```ruby
collection = Collection.new(..)
collection.save!
item = Item.new(collection: collection)
item.save!
```

As of the current version, relationships must be set on the owned side, so
doing something like `collection.items << item` is not possible. Also, notice
that we had to save both entities separately. ActiveMedusa doesn't cascade
these.

### Requesting a Slug 🐌

You can request that your new entity be given a particular URL slug in the
repository before you save it:

```ruby
item = Item.new
item.requested_slug = 'some-other-item'
item.save!
```

There is no guarantee, however, that the entity will actually receive this slug,
and no error will be raised if it doesn't.

For reasons related to Fedora performance, slugs are not advised.

## Updating Entities

Call `update` on an entity. (Bang version [!] also available.) This method
accepts a parameter list into which you can pass any updated `rdf_property`
value:

```ruby
item.update(some_rdf_property: 55)
```

## Deleting Entities

Call `delete` on an entity. This method accepts an optional boolean parameter
that will delete its tombstone as well.

## Loading Entities

*Note: Newly created entities cannot be loaded until the Solr index has been
committed. ActiveMedusa will not commit it automatically.*

To load an item by some property, you can use one of the finder methods, like
`find`, which will find by repository UUID:

```ruby
item = Item.find('some UUID')
```

If `find` finds multiple entities, it will return only one. This is the only
finder method that will raise an error if nothing is found.

Alternatively, you can find by repository URI:

```ruby
item = Item.find_by_uri('http://localhost:8080/fcrepo/rest/kumquats')
```

Then, there are the `find_by_x` methods, where `x` corresponds to some
`rdf_property`:

```ruby
item = Item.find_by_title('2003 Global Outlook for 6-Quart Slow-Cookers')
```

Once an entity has been loaded, it can be reloaded:

```ruby
item.reload!
```

### Loading Entities of Unknown Type

Suppose you have an entity URI or UUID, but you are unsure of the class of
the entity it identifies -- you don't know whether it's an `Item` or a
`Collection`, and therefore don't know which class `find` method to use. In
that case, you can call `find` on `ActiveMedusa::Container` to return an
instance of the correct class:

```ruby
item_or_collection = ActiveMedusa::Container.find('...')
```

### Reading & Writing Metadata

The item's complete RDF graph is available by calling `rdf_graph` on any entity
instance. This returns an `RDF::Graph` instance which you can read:

```ruby
item.rdf_graph.each_statement do |st|
  if st.predicate.to_s == 'http://purl.org/dc/elements/1.1/title'
    puts 'Title is: ' + st.object.to_s
  end
end
```

As well as write to:

```ruby
item.rdf_graph << [nil, RDF::URI('http://purl.org/dc/elements/1.1/title'),
    'Epistemology of the Kumquat']
```

You would then need to call `item.save` to persist this change.

### Other Useful Entity Methods

* `id`/`uuid` (returns the node's UUID)
* `created_at` (returns the RDF object of `fedora:created` as a `Time` object)
* `updated_at` (returns the RDF object of `fedora:lastModified` as a `Time`
  object)
* `repository_url` (returns the node's repository URI/URL)
* `destroyed?`
* `persisted?`

## Node Hierarchy Traversal

The `children` method will enable you to enumerate a container's LDP children:

```ruby
collection = Collection.find('..')
collection.children.each { |child| .. }
```

Likewise, a child can get its parent:

```ruby
parent = child.parent
```

Note that these will only work for parent or child containers that have a class
triple; see `entity_class_uri` above.

## Binary Entities

Binary entities work similarly to container entities. Using the example above,
a `Bytestream` can be initialized like an `Item`:

```ruby
b = Bytestream.new(parent_url: 'http://url/of/parent/container')
```

But before it can be saved, you will want to associate some data with it. You
can specify a file to upload:

```ruby
b.upload_pathname = File.join('path', 'to', 'a', 'file.tif')
```

Or, you can specify an external URL:

```ruby
b.external_resource_url = 'http://example.org/'
```

Optionally, but ideally, you should also specify the binary's media type:

```ruby
b.media_type = 'image/tiff'
```

At this point, you must save it before you can set any additional properties.
This is a limitation of ActiveMedusa. It can be saved just like a container:

```ruby
b.save!
puts b.repository_url # binary content now available here
```

Once the binary content has been saved, it cannot be changed. In Fedora,
binary nodes have supplementary metadata available at the `/fcr:metadata`
path under their URL. This is the only thing that will be updated when you
call `save` on an already-saved binary resource, A binary entity's RDF graph
is available via its `rdf_graph` accessor, just like a container.

### Accessing Binary Nodes

Binary nodes are not indexed in Solr. If you want to be able to retrieve them
later via ActiveMedusa, you need to make sure they are accessible via a
relationship with some other entity. In the example above, `Item` has a
one-to-many relationship with `Bytestream`, which makes its bytestreams
accessible via the `bytestreams` accessor:

```ruby
item = Item.find('..')
item.bytestreams.each { |b| .. }
```

## Searching For Entities

*Note 1: Newly added entities will not appear in search results until the Solr
index has been committed. ActiveMedusa will not commit it automatically.*

*Note 2: Newly created entities will not appear in search results in the
same thread unless enough time has elapsed for Solr to have received them,
which will rarely be the case. An ugly way of getting around this is to `sleep`
for a bit after saving an entity to wait for Solr to catch up - hoping that it
does in time. But it's best to simply not try to do it.*

*Note 3: Binary entities are not searchable (see **Binary Entities**).*

```ruby
items = Item.all.where(some_rdf_property: 'cats').
    where('arbitrary Solr condition')
```

Items are loaded when `to_a` is called, either explicitly or implicitly, such
as by `each`.

### Ordering

By default, results are sorted by relevance. To override this, use `order`
to sort by any sortable Solr field:

```ruby
Item.all.order('some_solr_field' => :asc)
Item.all.order('some_solr_field') # same effect as above
Item.all.order('some_solr_field' => :desc)
Item.all.order('some_solr_field desc')
```

### Counts

```ruby
items = Item.all
puts items.count # shortcut for items.to_a.total_length
```

### Start/Limit

```ruby
items = Item.all
puts items.start(20).limit(20)
```

### Faceting

You can add facet queries:

```ruby
Item.all.facet('creator:Napoleon%20Bonaparte')
Item.all.facet(['type:Book', 'subject:Citrus'])
```

To access returned facets, you might do something like:

```ruby
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
```

Faceting is enabled by default. To improve performance, you can turn it off if
you aren't using it:

```ruby
items = Item.where('...').facet(false)
```

### Relevance

If no sort order is provided (via `order`), results will be sorted by relevance.
A relevance score can be accessed via the transient `score` property of any
retrieved entity.

### "More Like This"

If you have the [MoreLikeThisHandler]
(https://wiki.apache.org/solr/MoreLikeThisHandler) enabled in Solr, you can
query by similarity:

```ruby
item = Item.find(id).more_like_this.limit(5)
```

## Transactions

Simply wrap any CRUD operation(s) inside a block:

```ruby
ActiveMedusa::Base.transaction do |tx_url|
  # Any code present here will occur within a transaction.
  # Raising an error will roll back the transaction.
  # Otherwise, it will commit automatically when the block ends.
end
```

Note: it is not possible to query within a transaction. (Fedora does not
dispatch messages about operations that happen inside transactions until they
have been committed.)

## Validation

`ActiveMedusa::Base` includes `ActiveModel::Model`, which supplies all the
validation functionality that ActiveRecord enjoys. So, you can use
ActiveRecord validation methods on your ActiveMedusa entities.

The only catch is that a property must be an `rdf_property` in order to be
validatable.

## Forms

Because `ActiveMedusa::Base` includes `ActiveModel::Model`, your ActiveMedusa
entities should work perfectly well with Rails' FormHelper. (Other form
frameworks are untested.)

## Callbacks

Your entities can use the following `ActiveModel::Model` callbacks:

* `before_create`
* `before_destroy`
* `before_load`
* `before_save`
* `before_update`
* `after_create`
* `after_destroy`
* `after_load`
* `after_save`
* `after_update`

Example:

```ruby
class Item < ActiveMedusa::Container
  before_save :do_something
  
  def do_something
  end
end
```

# Development

After checking out the repo, run `bin/setup` to install dependencies. Then,
run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`, and then
run `bundle exec rake release` to create a git tag for the version, push git
commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Debugging

`ActiveMedusa::Relation` has a `solr_response` method that you can use to
inspect the query and see the raw Solr results. Use it like this:

```ruby
items = Item.all.to_a # executes a Solr request
puts items.solr_response.inspect
```

Note that it will return `nil` until a request has been executed.

# Contributing

1. Fork it (https://github.com/[my-github-username]/active-medusa/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
