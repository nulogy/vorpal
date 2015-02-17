require 'vorpal/identity_map'
require 'vorpal/traversal'

module Vorpal
class AggregateRepository
  # @private
  def initialize(class_configs)
    configure(class_configs)
  end

  # Saves an aggregate to the DB. Inserts objects that are new to the
  # aggregate, updates existing objects and deletes objects that are no longer
  # present.
  #
  # Objects that are on the boundary of the aggregate (owned: false) will not
  # be inserted, updated, or deleted. However, the relationships to these
  # objects (provided they are stored within the aggregate) will be saved.
  #
  # @param object [Object] Root of the aggregate to be saved.
  # @return [Object] Root of the aggregate.
  def persist(object)
    mapping = {}
    serialize(object, mapping)
    new_objects = get_unsaved_objects(mapping.keys)
    set_primary_keys(object, mapping)
    set_foreign_keys(object, mapping)
    remove_orphans(object, mapping)
    save(object, mapping)
    object
  rescue
    nil_out_object_ids(new_objects)
    raise
  end

  # Like {#persist} but operates on multiple aggregates. Roots do not need to
  # be of the same type.
  #
  # @param objects [[Object]] array of aggregate roots to be saved.
  # @return [[Object]] array of aggregate roots.
  def persist_all(objects)
    objects.map(&method(:persist))
  end

  # Loads an aggregate from the DB. Will eagerly load all objects in the
  # aggregate and on the boundary (owned: false).
  #
  # @param id [Integer] Primary key value of the root of the aggregate to be
  #   loaded.
  # @param domain_class [Class] Type of the root of the aggregate to
  #   be loaded.
  # @param identity_map [Vorpal::IdentityMap] Provide your own IdentityMap instance
  #   if you want entity id - unique object mapping for a greater scope than one
  #   operation.
  # @return [Object] Entity with the given primary key value and type.
  def load(id, domain_class, identity_map=IdentityMap.new)
    load_all([id], domain_class, identity_map).first
  end

  # Like {#load} but operates on multiple ids.
  #
  # @param ids [[Integer]] Array of primary key values of the roots of the
  #   aggregates to be loaded.
  # @param domain_class [Class] Type of the roots of the aggregate to be loaded.
  # @param identity_map [Vorpal::IdentityMap] Provide your own IdentityMap instance
  #   if you want entity id - unique object mapping for a greater scope than one
  #   operation.
  # @return [[Object]] Entities with the given primary key values and type.
  def load_all(ids, domain_class, identity_map=IdentityMap.new)
    ids.map do |id|
      db_object = @configs.config_for(domain_class).load_by_id(id)
      hydrate(db_object, identity_map)
    end
  end

  # Removes an aggregate from the DB. Even if the aggregate contains unsaved
  # changes this method will correctly remove everything.
  #
  # @param object [Object] Root of the aggregate to be destroyed.
  # @return [Object] Root that was passed in.
  def destroy(object)
    config = @configs.config_for(object.class)
    db_object = config.find_in_db(object)
    @traversal.accept_for_db(db_object, DestroyVisitor.new())
    object
  end

  # Like {#destroy} but operates on multiple aggregates. Roots do not need to
  # be of the same type.
  #
  # @param objects [[Object]] Array of roots of the aggregates to be destroyed.
  # @return [[Object]] Roots that were passed in.
  def destroy_all(objects)
    objects.map(&method(:destroy))
  end

  private

  def configure(class_configs)
    @configs = MasterConfig.new(class_configs)
    @traversal = Traversal.new(@configs)
  end

  def hydrate(db_object, identity_map)
    deserialize(db_object, identity_map)
    set_associations(db_object, identity_map)
    identity_map.get(db_object)
  end

  def serialize(object, mapping)
    @traversal.accept_for_domain(object, SerializeVisitor.new(mapping))
  end

  def set_primary_keys(object, mapping)
    @traversal.accept_for_domain(object, IdentityVisitor.new(mapping))
    mapping.rehash # needs to happen because setting the id on an AR::Base model changes its hash value
  end

  def set_foreign_keys(object, mapping)
    @traversal.accept_for_domain(object, PersistenceAssociationVisitor.new(mapping))
  end

  def save(object, mapping)
    @traversal.accept_for_domain(object, SaveVisitor.new(mapping))
  end

  def remove_orphans(object, mapping)
    diff_visitor = AggregateDiffVisitor.new(mapping.values)
    @traversal.accept_for_db(mapping[object], diff_visitor)

    orphans = diff_visitor.orphans
    orphans.each { |o| @configs.config_for_db(o.class).destroy(o) }
  end

  def deserialize(db_object, identity_map)
    @traversal.accept_for_db(db_object, DeserializeVisitor.new(identity_map))
  end

  def set_associations(db_object, identity_map)
    @traversal.accept_for_db(db_object, DomainAssociationVisitor.new(identity_map))
  end

  def get_unsaved_objects(objects)
    objects.find_all { |object| object.id.nil? }
  end

  def nil_out_object_ids(objects)
    objects ||= []
    objects.each { |object| object.id = nil }
  end
end

# @private
class SerializeVisitor
  include AggregateVisitorTemplate

  def initialize(mapping)
    @mapping = mapping
  end

  def visit_object(object, config)
    serialize(object, config)
  end

  def continue_traversal?(association_config)
    association_config.owned
  end

  def serialize(object, config)
    db_object = serialize_object(object, config)
    @mapping[object] = db_object
  end

  def serialize_object(object, config)
    if config.serialization_required?
      attributes = config.serialize(object)
      if object.id.nil?
        config.build_db_object(attributes)
      else
        db_object = config.find_in_db(object)
        config.set_db_object_attributes(db_object, attributes)
        db_object
      end
    else
      object
    end
  end
end

# @private
class IdentityVisitor
  include AggregateVisitorTemplate

  def initialize(mapping)
    @mapping = mapping
  end

  def visit_object(object, config)
    set_primary_key(object, config)
  end

  def continue_traversal?(association_config)
    association_config.owned
  end

  private

  def set_primary_key(object, config)
    return unless object.id.nil?

    primary_key = config.get_primary_keys(1).first

    @mapping[object].id = primary_key
    object.id = primary_key
  end
end

# @private
class PersistenceAssociationVisitor
  include AggregateVisitorTemplate

  def initialize(mapping)
    @mapping = mapping
  end

  def visit_belongs_to(parent, child, belongs_to_config)
    belongs_to_config.set_foreign_key(@mapping[parent], child)
  end

  def visit_has_one(parent, child, has_one_config)
    return unless has_one_config.owned
    has_one_config.set_foreign_key(@mapping[child], parent)
  end

  def visit_has_many(parent, children, has_many_config)
    return unless has_many_config.owned
    children.each do |child|
      has_many_config.set_foreign_key(@mapping[child], parent)
    end
  end

  def continue_traversal?(association_config)
    association_config.owned
  end
end

# @private
class SaveVisitor
  include AggregateVisitorTemplate

  def initialize(mapping)
    @mapping = mapping
  end

  def visit_object(object, config)
    config.save(@mapping[object])
  end

  def continue_traversal?(association_config)
    association_config.owned
  end
end

# @private
class AggregateDiffVisitor
  include AggregateVisitorTemplate

  def initialize(db_objects_in_aggregate)
    @db_objects_in_aggregate = db_objects_in_aggregate
    @db_objects_in_db = []
  end

  def visit_object(db_object, config)
    @db_objects_in_db << db_object
  end

  def continue_traversal?(association_config)
    association_config.owned
  end

  def orphans
    @db_objects_in_db - @db_objects_in_aggregate
  end
end

# @private
class DeserializeVisitor
  include AggregateVisitorTemplate

  def initialize(identity_map)
    @identity_map = identity_map
  end

  def visit_object(db_object, config)
    deserialize_db_object(db_object, config)
  end

  private

  def deserialize_db_object(db_object, config)
    @identity_map.get_and_set(db_object) { config.deserialize(db_object) }
  end
end

# @private
class DomainAssociationVisitor
  include AggregateVisitorTemplate

  def initialize(identity_map)
    @identity_map = identity_map
  end

  def visit_belongs_to(db_object, db_child, belongs_to_config)
    associate_one_to_one(db_object, db_child, belongs_to_config)
  end

  def visit_has_one(db_parent, db_child, has_one_config)
    associate_one_to_one(db_parent, db_child, has_one_config)
  end

  def visit_has_many(db_object, db_children, has_many_config)
    associate_one_to_many(db_object, db_children, has_many_config)
  end

  private

  def associate_one_to_many(db_object, db_children, has_many_config)
    parent = @identity_map.get(db_object)
    children = @identity_map.map(db_children)
    has_many_config.set_children(parent, children)
  end

  def associate_one_to_one(db_parent, db_child, belongs_to_config)
    parent = @identity_map.get(db_parent)
    child = @identity_map.get(db_child)
    belongs_to_config.set_child(parent, child)
  end
end

# @private
class DestroyVisitor
  include AggregateVisitorTemplate

  def visit_object(object, config)
    config.destroy(object)
  end

  def continue_traversal?(association_config)
    association_config.owned
  end
end

end
