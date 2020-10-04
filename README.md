# Vorpal [![Build Status](https://travis-ci.com/nulogy/vorpal.svg?branch=master)](https://travis-ci.com/nulogy/vorpal) [![Code Climate](https://codeclimate.com/github/nulogy/vorpal/badges/gpa.svg)](https://codeclimate.com/github/nulogy/vorpal) [![Code Coverage](https://codecov.io/gh/nulogy/vorpal/branch/master/graph/badge.svg)](https://codecov.io/gh/nulogy/vorpal/branch/master)

Separate your domain model from your persistence mechanism. Some problems call for a really sharp tool.

> One, two! One, two! and through and through<br/>
> The vorpal blade went snicker-snack!<br/>
> He left it dead, and with its head<br/>
> He went galumphing back.

\- [Jabberwocky](https://www.poetryfoundation.org/poems/42916/jabberwocky) by Lewis Carroll

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
class Branch
  attr_accessor :id
  attr_accessor :length
  attr_accessor :diameter
  attr_accessor :tree

  def initialize(id: nil, length: 0, diameter: nil, tree: nil)
    @id, @length, @diameter, @tree = id, length, diameter, tree
  end
end

class Gardener
end

class Tree
  attr_accessor :id
  attr_accessor :name
  attr_accessor :gardener
  attr_accessor :branches

  def initialize(id: nil, name: "", gardener: nil, branches: [])
    @id, @name, @gardener, @branches = id, name, gardener, branches
  end
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

Here we've used the `owned: false` flag on the `belongs_to` from the Tree to the Gardener to show
that the Gardener is on the aggregate boundary.

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
1. No AR-style callbacks. Use [Infrastructure, Application, or Domain services](http://martinfowler.com/bliki/EvansClassification.html) instead.
1. No has-many-through associations. Use two has-many associations to a join entity instead.
1. The `id` attribute is reserved for database primary keys. If you have a natural key/id on your domain model, name it something that makes sense for your domain. It is the strong opinion of the authors that using natural keys as foreign keys is a bad idea. This mixes domain and persistence concerns.

## Constraints
1. Persisted entities must have getters and setters for all persisted attributes and associations. They do not need to be public.
1. Only supports PostgreSQL.

## Future Enhancements
* Support for UUID primary keys.
* Nicer DSL for specifying attributes that have different names in the domain model than in the DB.
* Show how to implement POROs without using Virtus (it is unsupported and can be crazy slow)
* Aggregate updated_at.
* Better support for value objects.

## FAQ

**Q.** Why do I care about separating my persistence mechanism from my domain models?

**A.** It generally comes back to the [Single Responsibility Principle](http://en.wikipedia.org/wiki/Single_responsibility_principle). Here are some resources for the curious:
* [Architecture, the Lost Years](https://www.youtube.com/watch?v=WpkDN78P884) - talk by Bob Martin.
* [Hexagonal Architecture Pattern](http://alistair.cockburn.us/Hexagonal+architecture) - Alistair Cockburn.
* [Perpetuity](https://github.com/jgaskins/perpetuity) - a Ruby [Data Mapper](http://martinfowler.com/eaaCatalog/dataMapper.html)-style ORM.
* [EDR](http://victorsavkin.com/post/41016739721/building-rich-domain-models-in-rails-separating) - another [Data Mapper](http://martinfowler.com/eaaCatalog/dataMapper.html)-style ORM framelet by Victor Savkin.

**Q.** How do I do more complicated queries against the DB without direct access to ActiveRecord?

**A.** Create a method on a [Repository](http://martinfowler.com/eaaCatalog/repository.html)! They have full access to the DB/ORM so you can use [Arel](https://github.com/rails/arel) and go [crazy](http://asciicasts.com/episodes/239-activerecord-relation-walkthrough) or use direct SQL if you want. 

For example, use the [#query](https://rubydoc.info/github/nulogy/vorpal/master/Vorpal/AggregateMapper#query-instance_method) method on the [AggregateMapper](https://rubydoc.info/github/nulogy/vorpal/master/Vorpal/AggregateMapper) to access the underyling [ActiveRecordRelation](https://api.rubyonrails.org/classes/ActiveRecord/Relation.html):

```ruby
  def find_special_ones
    # use `load_all` or `load_one` to convert from ActiveRecord objects to domain POROs.
    @mapper.query.where(special: true).load_all 
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

**Q.** Are `updated_at` and `created_at` supported?

**A.** Yes. If they exist on your database tables, they will behave exactly as if you were using vanilla ActiveRecord.

## Contributing

1. Fork it ( https://github.com/nulogy/vorpal/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## OSX Environment setup

1. Install [Homebrew](https://brew.sh/)
2. Install [rbenv](https://github.com/rbenv/rbenv#installation) ([RVM](https://rvm.io/) can work too)
3. Install [DirEnv](https://direnv.net/docs/installation.html) (`brew install direnv`)
4. Install Docker Desktop Community Edition (`brew cask install docker`)
5. Start Docker Desktop Community Edition (`CMD+space docker ENTER`)
6. Install Ruby (`rbenv install 2.7.0`)
7. Install PostgreSQL (`brew install postgresql`)
8. Clone the repo (`git clone git@github.com:nulogy/vorpal.git`) and `cd` to the project root.
8. Copy the contents of `gemfiles/rails_<version>.gemfile.lock` into a `Gemfile.lock` file
  at the root of the project. (`cp gemfiles/rails_6_0.gemfile.lock gemfile.lock`)
9. `bundle`

### Running Tests

1. Start a PostgreSQL server using `docker-compose up`
3. Run `rake` from the terminal to run all specs or `rspec <path to spec file>` to
  run a single spec.

### Running Tests for a specific version of Rails

1. Start a PostgreSQL server using `docker-compose up`
2. Run `appraisal rails-5-2 rake` from the terminal to run all specs or
  `appraisal rails-5-2 rspec <path to spec file>` to run a single spec.

Please see the [Appraisal gem docs](https://github.com/thoughtbot/appraisal) for more information.

## Contributors

See who's [contributed](https://github.com/nulogy/vorpal/graphs/contributors)!
