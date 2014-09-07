# Vorpal

Separate your domain model from your persistence mechanism. Some problems call for a really sharp tool.


> One, two! One, two! and through and through

> The vorpal blade went snicker-snack!

> He left it dead, and with its head

> He went galumphing back.


## Overview
Vorpal is a [Data Mapper](http://martinfowler.com/eaaCatalog/dataMapper.html)-style ORM (object relational mapper) framelet that persists POROs (plain old Ruby objects) to a relational DB. It has been heavily influenced by concepts from [Domain Driven Design](http://www.infoq.com/minibooks/domain-driven-design-quickly).

We say 'framelet' because it doesn't attempt to give you all the goodies that ORMs usually provide. Instead, it layers on top of an existing ORM and allows you to take advantage of the ease of the [Active Record](http://www.martinfowler.com/eaaCatalog/activeRecord.html) pattern where appropriate and the power of the [Data Mapper](http://martinfowler.com/eaaCatalog/dataMapper.html) pattern when you need it.

3 things set it apart from existing main-stream Ruby ORMs ([ActiveRecord](http://api.rubyonrails.org/files/activerecord/README_rdoc.html), [Datamapper](http://datamapper.org/), and [Sequel](http://sequel.jeremyevans.net/)):

1. It keeps persistence concerns separate from domain logic. In other words, your domain models don't have to extend ActiveRecord::Base (or something else) in order to get saved to a DB.
1. It works with [Aggregates](http://martinfowler.com/bliki/DDD_Aggregate.html) rather than individual objects.
1. It plays nicely with ActiveRecord objects!

This last point is incredibly important because applications that grow organically can get very far without needing to separate persistence and domain logic. But when they do, Vorpal will play nicely with all that legacy code.

## Resources
Need to know why mixing domain logic and persistence isn't always the best? Here you go.

* [Perpetuity](https://github.com/jgaskins/perpetuity) - a Ruby [Data Mapper](http://martinfowler.com/eaaCatalog/dataMapper.html)-style ORM.
* [EDR](http://victorsavkin.com/post/41016739721/building-rich-domain-models-in-rails-separating) - another [Data Mapper](http://martinfowler.com/eaaCatalog/dataMapper.html)-style ORM framelet by Victor Savkin.
* [Architecture, the Lost Years](https://www.youtube.com/watch?v=WpkDN78P884) - talk by Bob Martin
* [Hexagon Architecture Pattern](http://alistair.cockburn.us/Hexagonal+architecture) - Alistair Cockburn

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
Start with a domain model of POROs and AR::Base objects that form an aggregate:

```ruby
class Tree; end

class Branch
  include Virtus.model

  attribute :id, Integer
  attribute :length, Decimal
  attribute :diameter, Decimal
  attribute :tree, Tree
end

class Gardener < ActiveRecord::Base
end

class Tree
  include Virtus.model

  attribute :id, Integer
  attribute :name, String
  attribute :gardener, Gardener
  attribute :branches, Array[Branch]
end
```

In this aggregate, the Tree is the root and the Branches are inside the aggregate boundary. The Gardener is not technically part of the aggregate but is required for the aggregate to make sense so we say that it is on the aggregate boundary.

POROs must have setters and getters for all fields and associations that are to be persisted. They must also provide a no argument constructor.

Along with a relational model (in PostgreSQL):

```sql
CREATE TABLE trees
(
  id serial NOT NULL,
  name text,
  gardener_id integer
);

CREATE TABLE gardeners
(
  id serial NOT NULL,
  name text
);

CREATE TABLE branches
(
  id serial NOT NULL,
  length numeric,
  diameter numeric,
  tree_id integer
);
```

Create a repository configured to persist the aggregate to the relational model:

```ruby
require 'vorpal'

module TreeRepository
  extend self
  
  @repository = Vorpal.define do
    map Tree do
      fields :name
      belongs_to :gardener, owned: false
      has_many :branches
    end

    map Gardener
  
    map Branch do
      fields :length, :diameter
      belongs_to :tree
    end
  end
  
  def find(id)
    @repository.load(id, Tree)
  end
  
  def save(tree)
    @repository.persist(tree)
  end
  
  def destroy(tree)
    @repository.destroy(tree)
  end
  
  class ARTree < ActiveRecord::Base
    self.table_name = 'trees'
  end
  
  class ARBranch < ActiveRecord::Base
    self.table_name = 'branches'
  end
end
```

Here we've used the `owned` flag on the `belongs_to` from the Tree to the Gardener to show that the Gardener is on the aggregate boundary.

And use it:

```ruby
# Saves/updates the given Tree as well as all Branches referenced by it,
# but not Gardeners.
TreeRepository.save(big_tree)

# Loads the given Tree as well as all Branches and Gardeners 
# referenced by it.
small_tree = TreeRepository.find(small_tree_id)

# Destroys the given Tree as well as all Branches referenced by it,
# but not Gardeners.
TreeRepository.destroy(dead_tree)
```

## API Documentation

http://rubydoc.info/github/nulogy/vorpal/master/frames

## Caveats
It also does not do some things that you might expect from other ORMs:

1. No lazy loading of associations. This might sound like a big deal, but with [correctly designed aggregates](http://dddcommunity.org/library/vernon_2011/) it turns out not to be.
1. No managing of transactions. It is the strong opinion of the authors that managing transactions is an application-level concern.
1. No support for validations. Validations are not a persistence concern.
1. Has a dependency on ActiveRecord.
1. No facilities for doing arbitrary queryies against the DB.
1. No callbacks.

## Constraints
1. Persisted entities must have getters and setters for all persisted fields and associations. They do not need to be public.
1. Only supports primary keys called `id`.
1. Primary key values must be generated by Vorpal.
1. Only supports PostgreSQL.
1. Identity map only applies to a single call to `#load` or `#load_all`.

## Future Enhancements
* Aggregate updated_at.
* Support for other DBMSs.
* Support for other ORMs.
* Identity map for an entire application transaction.
* Value objects.
* Remove dependency on ActiveRecord (optimistic locking? connection pooling? migrations? DDL DSL? Copy DB structure to test DB?)
* Application-generated primary key ids.
* More efficient object loading (use fewer queries.)
* Single table inheritance?
* Different fields names in domain models than in the DB.

## Contributing

1. Fork it ( https://github.com/nulogy/vorpal/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
