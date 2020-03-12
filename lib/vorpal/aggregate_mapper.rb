require 'vorpal/identity_map'

module Vorpal
  class AggregateMapper
    # @private
    def initialize(domain_class, engine)
      @domain_class = domain_class
      @engine = engine
    end

    # Saves a collection of aggregates to the DB. Inserts objects that are new to an
    # aggregate, updates existing objects and deletes objects that are no longer
    # present.
    #
    # Objects that are on the boundary of an aggregate (owned: false) will not
    # be inserted, updated, or deleted. However, the relationships to these
    # objects (provided they are stored within an aggregate) will be saved.
    #
    # @param roots [[Object]] array of aggregate roots to be saved. Will also accept a
    #   single aggregate.
    # @return [[Object]] array of aggregate roots.
    # @raise [InvalidAggregateRoot] When any of the roots are nil.
    def persist(roots)
      @engine.persist(roots)
    end

    # Loads an aggregate from the DB. Will eagerly load all objects in the
    # aggregate and on the boundary (owned: false).
    #
    # @param db_root [Object] DB representation of the root of the aggregate to be
    #   loaded. This can be nil.
    # @param identity_map [IdentityMap] Provide your own IdentityMap instance
    #   if you want entity id -> unique object mapping for a greater scope than one
    #   operation.
    # @return [Object] Aggregate root corresponding to the given DB representation.
    def load_one(db_root, identity_map=IdentityMap.new)
      @engine.load_one(db_root, @domain_class, identity_map)
    end

    # Like {#load_one} but operates on multiple aggregate roots.
    #
    # @param db_roots [[Integer]] Array of primary key values of the roots of the
    #   aggregates to be loaded.
    # @param identity_map [IdentityMap] Provide your own IdentityMap instance
    #   if you want entity id -> unique object mapping for a greater scope than one
    #   operation.
    # @return [[Object]] Aggregate roots corresponding to the given DB representations.
    # @raise [InvalidAggregateRoot] When any of the db_roots are nil.
    def load_many(db_roots, identity_map=IdentityMap.new)
      @engine.load_many(db_roots, @domain_class, identity_map)
    end

    # Removes a collection of aggregates from the DB. Even if an aggregate
    # contains unsaved changes this method will correctly remove everything.
    #
    # @param roots [[Object]] Roots of the aggregates to be destroyed. Also accepts a
    #   single root.
    # @return [[Object]] Roots that were passed in.
    # @raise [InvalidAggregateRoot] When any of the roots are nil.
    def destroy(roots)
      @engine.destroy(roots)
    end

    # Removes a collection of aggregates from the DB given their primary keys.
    #
    # @param ids [[Integer]] Ids of roots of the aggregates to be destroyed. Also
    #   accepts a single id.
    # @raise [InvalidPrimaryKeyValue] When any of the ids are nil.
    def destroy_by_id(ids)
      @engine.destroy_by_id(ids, @domain_class)
    end

    # Returns the DB Class (e.g. ActiveRecord::Base class) that is responsible
    # for accessing the associated data in the DB.
    def db_class
      @engine.db_class(@domain_class)
    end

    # Access to the underlying mapping {Engine}. Provided in case access to another aggregate
    # or another db_class is required.
    #
    # @return [Engine] Mapping interface not specific to a particular aggregate root.
    def engine
      @engine
    end

    # Returns a 'Vorpal-aware' [ActiveRecord::Relation](https://api.rubyonrails.org/classes/ActiveRecord/Relation.html)
    # for the ActiveRecord object underlying the domain entity mapped by this mapper.
    #
    # This method allows you to easily access the power of ActiveRecord::Relation to do more complex
    # queries in your repositories.
    #
    # The ActiveRecord::Relation is 'Vorpal-aware' because it has the {#load_one} and {#load_many} methods
    # mixed in so that you can get the POROs from your domain model instead of the ActiveRecord
    # objects normally returned by ActiveRecord::Relation.
    #
    # @return [ActiveRecord::Relation]
    def query
      @engine.query(@domain_class)
    end
  end
end
