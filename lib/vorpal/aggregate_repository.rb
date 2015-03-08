require 'vorpal/identity_map'
require 'vorpal/traversal'
require 'vorpal/db_loader'

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
    persist_all(Array(object)).first
  end

  # Like {#persist} but operates on multiple aggregates. Roots do need to
  # be of the same type.
  #
  # @param objects [[Object]] array of aggregate roots to be saved.
  # @return [[Object]] array of aggregate roots.
  def persist_all(objects)
    return objects if objects.empty?

    mapping = {}
    new_objects = []
    loaded_db_objects = load_owned_from_db(objects.map(&:id), objects.first.class)
    objects.each do |object|
      serialize(object, mapping, loaded_db_objects)
      new_objects.concat(get_unsaved_objects(mapping.keys))
      set_primary_keys(object, mapping)
      set_foreign_keys(object, mapping)
    end
    remove_orphans(mapping, loaded_db_objects)
    save(objects, mapping)
    return objects
  rescue
    nil_out_object_ids(new_objects)
    raise
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
    db_objects = load_from_db(ids, domain_class).all_objects

    hydrate(db_objects, identity_map)
    identity_map.map_raw(ids, @configs.config_for(domain_class).db_class)
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

  def load_from_db(ids, domain_class, only_owned=false)
    DbLoader.new(@configs, only_owned).load_from_db(ids, domain_class)
    # old_load_from_db(ids, domain_class, only_owned)
  end

  def load_owned_from_db(ids, domain_class)
    load_from_db(ids, domain_class, true)
  end

  def old_load_from_db(ids, domain_class, only_owned)
    loaded_objects = LoadedObjects.new
    Array(ids).each do |id|
      config = @configs.config_for(domain_class)
      db_object = config.load_by_id(id)
      load_from_db_visitor = LoadFromDBVisitor.new(only_owned, loaded_objects)
      @traversal.accept_for_db(db_object, load_from_db_visitor)
    end
    loaded_objects
  end

  def hydrate(db_objects, identity_map)
    db_objects.each do |db_object|
      identity_map.get_and_set(db_object) { @configs.config_for_db(db_object.class).deserialize(db_object) }
    end

    db_objects.each do |db_object|
      config = @configs.config_for_db(db_object.class)
      config.has_manys.each do |has_many_config|
        db_children = find_associated(db_object, has_many_config, db_objects)
        associate_one_to_many(db_object, db_children, has_many_config, identity_map)
      end

      config.has_ones.each do |has_one_config|
        db_children = find_associated(db_object, has_one_config, db_objects)
        associate_one_to_one(db_object, db_children.first, has_one_config, identity_map)
      end

      config.belongs_tos.each do |belongs_to_config|
        db_children = find_associated(db_object, belongs_to_config, db_objects)
        associate_one_to_one(db_object, db_children.first, belongs_to_config, identity_map)
      end
    end
  end

  def find_associated(db_object, association_config, db_objects)
    db_objects.find_all do |db_child|
      association_config.associated?(db_object, db_child)
    end
  end

  def associate_one_to_many(db_object, db_children, one_to_many, identity_map)
    parent = identity_map.get(db_object)
    children = identity_map.map(db_children)
    one_to_many.set_children(parent, children)
  end

  def associate_one_to_one(db_parent, db_child, one_to_one_config, identity_map)
    parent = identity_map.get(db_parent)
    child = identity_map.get(db_child)
    one_to_one_config.set_child(parent, child)
  end

  def configure(class_configs)
    @configs = MasterConfig.new(class_configs)
    @traversal = Traversal.new(@configs)
  end

  def serialize(object, mapping, loaded_db_objects)
    @traversal.accept_for_domain(object, SerializeVisitor.new(mapping, loaded_db_objects))
  end

  def set_primary_keys(object, mapping)
    @traversal.accept_for_domain(object, IdentityVisitor.new(mapping))
    mapping.rehash # needs to happen because setting the id on an AR::Base model changes its hash value
  end

  def set_foreign_keys(object, mapping)
    @traversal.accept_for_domain(object, PersistenceAssociationVisitor.new(mapping))
  end

  def save(objects, mapping)
    objects.each do |object|
      @traversal.accept_for_domain(object, SaveVisitor.new(mapping))
    end
  end

  def remove_orphans(mapping, loaded_db_objects)
    db_objects_in_aggregate = mapping.values
    db_objects_in_db = loaded_db_objects.all_objects
    orphans = db_objects_in_db - db_objects_in_aggregate

    orphans.each { |o| @configs.config_for_db(o.class).destroy(o) }
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

  def initialize(mapping, loaded_db_objects)
    @mapping = mapping
    @loaded_db_objects = loaded_db_objects
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
        db_object = @loaded_db_objects.find_by_id(object, config)
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
class LoadFromDBVisitor
  include AggregateVisitorTemplate

  def initialize(only_owned, loaded_objects)
    @only_owned = only_owned
    @loaded_objects = loaded_objects
  end

  def visit_object(db_object, config)
    @loaded_objects.add(config, db_object)
  end

  def continue_traversal?(association_config)
    !@only_owned || association_config.owned == true
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
