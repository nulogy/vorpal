# Vorpal

Separate your domain model from your delivery mechanism.

## Overview
Vorpal is a [Data Mapper](http://martinfowler.com/eaaCatalog/dataMapper.html)-style ORM (object relational mapper) framelet that persists POROs (plain old Ruby objects) to a relational DB.

We say 'framelet' because it doesn't attempt to give you all the goodies that ORMs usually provide. Instead, it layers on top of an existing ORM and allows you to use the simplicity of the Active Record pattern where appropriate and the power of the Data Mapper pattern when you need it.

3 things set it apart from existing Ruby ORMs (ActiveRecord and Datamapper):

1. It keeps persistence concerns separate from domain logic. In other words, your domain models don't have to extend ActiveRecord::Base (or something else) in order to get saved to a DB.
1. It works with [Aggregates](http://martinfowler.com/bliki/DDD_Aggregate.html) rather than individual objects.
1. It plays nicely with ActiveRecord objects!

[Perpetuity](https://github.com/jgaskins/perpetuity) has a great introduction.

Talk about EDR? Victor has a good explanation of why domain model and delivery mechanism should be separated.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'vorpal'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install vorpal

## Usage
Start with a domain model of POROs that form an aggregate:

```ruby
class Tree; end

class Trunk
  include Virtus.model

  attribute :id, Integer
  attribute :length, Decimal
  attribute :tree, Tree
end

class Branch
  include Virtus.model

  attribute :id, Integer
  attribute :length, Decimal
  attribute :tree, Tree
end

class Tree
  include Virtus.model

  attribute :id, Integer
  attribute :name, String
  attribute :trunk, Trunk
  attribute :branches, Array[Branch]
end
```

Along with a relational model:

```sql
CREATE TABLE trees
(
  id serial NOT NULL,
  name text,
  trunk_id integer
)

CREATE TABLE trunks
(
  id serial NOT NULL,
  length numeric
)

CREATE TABLE branches
(
  id serial NOT NULL,
  length numeric,
  tree_id integer
)
```

Create a repository configured to persist the aggregate to the relational model:

```ruby
repository = Persistence::Configuration.define do
  map Tree do
    fields :name
    belongs_to :trunk
    has_many :branches
  end

  map Trunk do
    fields :length
    has_one :tree
  end
  
  map Branch do
    fields :length
    belongs_to :tree
  end
end
```
Why don't we use DDD language? I see no mention of aggregates and entities!

And use it:

```ruby
repository.persist(big_tree)

small_tree = repository.load(small_tree_id, Tree)

repository.destroy(dead_tree)
```

Show implementation of a repository using the aggregate repository!!!

Talk about aggregate boundary.

### With ActiveRecord
TBD

## API Documentation

(http://rubydoc.info/github/nulogy/vorpal/master/frames)

## Caveats
It also does not do some things that you might expect from other ORMs:

1. There is no lazy loading of associations. This might sound like a big deal, but with [correctly designed aggregates](http://dddcommunity.org/library/vernon_2011/) it turns out to be very minor.
1. There is no managing of transactions. It is the strong opinion of the authors that managing transactions is an application-level concern.
1. No support for validations. Validations are not a persistence concern.
1. Only supports primary keys called `id`.
1. Only supports PostgreSQL.
1. Requires domain entities to have a special implementation of `#initialize`.
1. Has a dependency on ActiveRecord.
1. No facilities for querying the DB.
1. Identity map only applies to a single `#load` or `#load_all` call.
1. Clients cannot specify primary key values.

## Future Enhancements
* Aggregate updated_at.
* Support for other DBMSs.
* Identity map for an entire application transaction.
* Value objects.
* Remove dependency on ActiveRecord (optimistic locking? connection pooling?)
* Application-generated primary key ids.
* More efficient object loading (use fewer queries.)
* Do not require special `#initialize` method? Provide a hook for an instance factory?
* Single table inheritance?

## Contributing

1. Fork it ( https://github.com/nulogy/vorpal/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
