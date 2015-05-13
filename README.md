ActiveMedusa provides a simple ActiveRecord-like interface to a Fedora 4
repository, using Solr for lookup and querying.

# Features

* Customizable Fedora ontology. Create your own RDF predicates or use existing
  ones. (ActiveMedusa does require some custom predicates, but they are
  managed automatically and live in their own distinct namespace.)
* Customizable Solr schema. The names and types of your fields are up to you.
* No-configuration support for node hierarchy traversal.
* Simple and lightweight.

# Differences compared to ActiveFedora

* ActiveMedusa does not populate Solr itself; instead, it delegates this job to
  fcrepo-message-consumer or fcrepo-camel. This means that it never writes to
  Solr and has nothing to do with keeping it updated.
* Not as good at modeling complex RDF ontologies.
* No association with Hydra.
* Simpler, easier to understand, approximately an order of magnitude simpler.
  (Then again, it also does an order of magnitude less.)
* No support for Fedora 3.

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
      config.namespace_prefix = 'example'
      config.namespace_uri = 'http://example.org/'
      config.solr_url = 'http://localhost:8983/solr'
      config.solr_core = 'collection1'
      config.solr_class_field = :class # used by ActiveMedusa finder methods
      config.solr_uuid_field = :uuid
      config.solr_default_search_field = :searchall
      config.solr_facet_fields = [:collection_facet, :creator_facet,
                                  :date_facet, :format_facet, :language_facet]
    end

If you are using Rails, you would put this in
`config/initializers/active_medusa.rb`, and then restart your server.

## Defining Entities

Let's declare some entity ("model") classes. `Collection` and `Item` will
correspond to Fedora 4 container nodes, and `Bytestream` will correspond to
Fedora binary nodes. These are all common entities found in many repositories,
but you could just as easily use `Series` instead of `Collection`, `Book`
instead of `Item`, etc.

    # collection.rb
    class Collection < ActiveMedusa::Relation
      has_many :items
      # TODO: rdf_property
    end

    # item.rb
    class Item < ActiveMedusa::Relation
      has_many :bytestreams
      belongs_to :collection
      # TODO: rdf_property
    end
    
    # bytestream.rb
    class Bytestream < ActiveMedusa::Relation
      belongs_to :item
      # TODO: rdf_property
    end

TODO: go over has_many, belongs_to, and rdf_property

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

You can request that your new entity be given a particular slug before you save
it:

    item = Item.new
    item.requested_slug = 'cats'
    item.save!
    
There is no guarantee, however, that the entity will actually get this slug.

## Updating Entities

Simply call `update` an an entity. (Bang version [!] also available.)

## Deleting Entities

Call `delete` on an entity. This method accepts an optional boolean
`also_tombstone` parameter that will delete its tombstone as well.

## Loading Entities

To load an item by some property, you can use one of the finder methods, like
`find`, which will find by repository UUID:

    item = Item.find('some UUID')

This method will raise an error if nothing is found, and if multiple entities
are found, it will return only one.

Additionally, you can find by repository URI:

    item = Item.find_by_uri('F4 node URI')

Or by web ID:

    item = Item.find_by_web_id('t3s8w')

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

*Note: Newly created entities will not appear in search results in the
same thread unless enough time has elapsed for Solr to have received them from
fcrepo-camel/fcrepo-message-consumer, which is rarely the case. An easy and
ugly way of getting around this is to `sleep` for a bit after saving an entity
to wait for it to catch up - hoping that it does in time. But it's best to
simply not try to do it.*

    items = Item.all.where(some_property: 'cats').
        where('arbitrary Solr query').
        order('some_solr_field' => 'asc').start(21).limit(20)

Items are loaded when `to_a` is called, explicitly or implicitly. So:

    items.each do |item|
      # At this point, the Solr query has been executed, and items will be
      # loaded one-by-one from Fedora with each iteration of the loop.
      # TODO: is the above true or are they loaded all at once?
    end

### Counts

    items.count # shortcut for items.to_a.total_length

This method simply returns the count provided by Solr, so it's fast.

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
        puts term.label # TODO: ??
        puts term.name # TODO: ??
      end
    end

### Scoring

If no sort order is provided (via `order`), results will be sorted by score.
A result score can be accessed from the `score` property of any retrieved
entity.

### "More Like This"

If you have the MoreLikeThisHandler enabled in Solr, you can do queries by
similarity:

    Item.find_by_id(id).more_like_this.limit(5)

TODO: tell how to enable it

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
entities should work perfectly well with Rails' FormHelper.

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

# Contributing

1. Fork it (https://github.com/[my-github-username]/active-medusa/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
