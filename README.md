# Vorpal [![Build Status](https://travis-ci.org/nulogy/vorpal.svg?branch=master)](https://travis-ci.org/nulogy/vorpal) [![Code Climate](https://codeclimate.com/github/nulogy/vorpal/badges/gpa.svg)](https://codeclimate.com/github/nulogy/vorpal)

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

For more details on why we created Vorpal, see [The Pitch](https://github.com/nulogy/vorpal/wiki#the-pitch).

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

In this aggregate, the Tree is the root and the Branches are inside the aggregate boundary. The Gardener is not technically part of the aggregate but is required for the aggregate to make sense so we say that it is on the aggregate boundary. Only objects that are inside the aggregate boundary will be saved, updated, or destroyed by Vorpal.

POROs must have setters and getters for all attributes and associations that are to be persisted. They must also provide a no argument constructor.

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

  engine = Vorpal.define do
    map Tree do
      attributes :name
      belongs_to :gardener, owned: false
      has_many :branches
    end

    map Gardener, to: Gardener

    map Branch do
      attributes :length, :diameter
      belongs_to :tree
    end
  end
  @mapper = engine.mapper_for(Tree)

  def find(tree_id)
    @mapper.query.where(id: tree_id).load_one
  end

  def save(tree)
    @mapper.persist(tree)
  end

  def destroy(tree)
    @mapper.destroy(tree)
  end

  def destroy_by_id(tree_id)
    @mapper.destroy_by_id(tree_id)
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

# Or
TreeRepository.destroy_by_id(dead_tree_id)
```

## API Documentation

http://rubydoc.info/github/nulogy/vorpal/master/frames

## Caveats
It also does not do some things that you might expect from other ORMs:

1. No lazy loading of associations. This might sound like a big deal, but with [correctly designed aggregates](http://dddcommunity.org/library/vernon_2011/) it turns out not to be.
1. No managing of transactions. It is the strong opinion of the authors that managing transactions is an application-level concern.
1. No support for validations. Validations are not a persistence concern.
1. No AR-style callbacks. Use Infrastructure, Application, or Domain [services](http://martinfowler.com/bliki/EvansClassification.html) instead.
1. No has-many-through associations. Use two has-many associations to a join entity instead.
1. The `id` attribute is reserved for database primary keys. If you have a natural key/id on your domain model, name it something that makes sense for your domain. It is the strong opinion of the authors that using natural keys as foreign keys is a bad idea. This mixes domain and persistence concerns.

## Constraints
1. Persisted entities must have getters and setters for all persisted attributes and associations. They do not need to be public.
1. Only supports PostgreSQL.

## Future Enhancements
* Aggregate updated_at.
* Support for other DBMSs (no MySQL support until ids can be generated without inserting into a table!)
* Support for other ORMs.
* Value objects.
* Remove dependency on ActiveRecord (optimistic locking? updated_at, created_at support? Data type conversions? TimeZone support?)
* More efficient updates (use fewer queries.)
* Nicer DSL for specifying attributes that have different names in the domain model than in the DB.

## FAQ

**Q.** Why do I care about separating my persistence mechanism from my domain models?

**A.** It generally comes back to the [Single Responsibility Principle](http://en.wikipedia.org/wiki/Single_responsibility_principle). Here are some resources for the curious:
* [Architecture, the Lost Years](https://www.youtube.com/watch?v=WpkDN78P884) - talk by Bob Martin.
* [Hexagonal Architecture Pattern](http://alistair.cockburn.us/Hexagonal+architecture) - Alistair Cockburn.
* [Perpetuity](https://github.com/jgaskins/perpetuity) - a Ruby [Data Mapper](http://martinfowler.com/eaaCatalog/dataMapper.html)-style ORM.
* [EDR](http://victorsavkin.com/post/41016739721/building-rich-domain-models-in-rails-separating) - another [Data Mapper](http://martinfowler.com/eaaCatalog/dataMapper.html)-style ORM framelet by Victor Savkin.

**Q.** How do I do more complicated queries against the DB without direct access to ActiveRecord?

**A.** Create a method on a [Repository](http://martinfowler.com/eaaCatalog/repository.html)! They have full access to the DB/ORM so you can use [Arel](https://github.com/rails/arel) and go [crazy](http://asciicasts.com/episodes/239-activerecord-relation-walkthrough) or use direct SQL if you want. 

For example:

```ruby
  def find_all
    @mapper.query.load_all # use the mapper to load all the aggregates
  end
```

**Q.** How do I do validations now that I don't have access to ActiveRecord anymore?

**A.** Depends on what kind of validations you want to do:
* For validating single attributes on a model: [ActiveModel::Validations](http://api.rubyonrails.org/classes/ActiveModel/Validations.html) work very well.
* For validating whole objects or object compositions (like the state of an Aggregate): Validator objects are preferred. Chapter 5 of [Implementing Domain Driven Design](https://vaughnvernon.co/?page_id=168) contains more guidance.

**Q.** How do I use Rails view helpers like [`form_for`](http://api.rubyonrails.org/classes/ActionView/Helpers/FormHelper.html#method-i-form_for)?

**A.** Check out [ActiveModel::Model](http://api.rubyonrails.org/classes/ActiveModel/Model.html). For more complex use-cases consider using a [Form](http://rhnh.net/2012/12/03/form-objects-in-rails) [Object](https://www.reinteractive.net/posts/158-form-objects-in-rails).

**Q.** How do I get dirty checking?

**A.** Check out [ActiveModel::Dirty](http://api.rubyonrails.org/classes/ActiveModel/Dirty.html).

**Q.** How do I get serialization?

**A.** You can use [ActiveModel::Serialization](http://api.rubyonrails.org/classes/ActiveModel/Serialization.html) or [ActiveModel::Serializers](https://github.com/rails-api/active_model_serializers) but they are not heartily recommended. The former is too coupled to the model and the latter is too coupled to Rails controllers. Vorpal uses [SimpleSerializer](https://github.com/nulogy/simple_serializer) for this purpose.

## Running Tests

1. Start a PostgreSQL server.
2. Either:
  * Create a DB user called `vorpal` with password `pass`. OR:
  * Modify `spec/helpers/db_helpers.rb`.
3. Run `rake` from the terminal.

## Contributors

* [Sean Kirby](https://github.com/sskirby)
* [Paul Sobocinski](https://github.com/psobocinski)
* [Jason Cheong-Kee-You](https://github.com/jchunky)

## Contributing

1. Fork it ( https://github.com/nulogy/vorpal/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
