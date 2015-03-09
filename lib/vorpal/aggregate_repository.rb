require 'vorpal/identity_map'
require 'vorpal/traversal'
require 'vorpal/db_loader'
require 'vorpal/naive_db_loader'

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
  def persist(root)
    persist_all(Array(root)).first
  end

  # Like {#persist} but operates on multiple aggregates. Roots must
  # be of the same type.
  #
  # @param objects [[Object]] array of aggregate roots to be saved.
  # @return [[Object]] array of aggregate roots.
  def persist_all(roots)
    return roots if roots.empty?

    all_owned_objects = all_owned_objects(roots)
    mapping = {}
    loaded_db_objects = load_owned_from_db(roots.map(&:id), roots.first.class)

    serialize(all_owned_objects, mapping, loaded_db_objects)
    new_objects = get_unsaved_objects(mapping.keys)
    set_primary_keys(all_owned_objects, mapping)
    set_foreign_keys(all_owned_objects, mapping)
    remove_orphans(mapping, loaded_db_objects)
    save(all_owned_objects, mapping)

    return roots
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
    deserialize(db_objects, identity_map)
    set_associations(db_objects, identity_map)

    identity_map.map_raw(ids, @configs.config_for(domain_class).db_class)
  end

  # Removes an aggregate from the DB. Even if the aggregate contains unsaved
  # changes this method will correctly remove everything.
  #
  # @param object [Object] Root of the aggregate to be destroyed.
  # @return [Object] Root that was passed in.
  def destroy(root)
    destroy_all(Array(root)).first
  end

  # Like {#destroy} but operates on multiple aggregates. Roots must
  # be of the same type.
  #
  # @param objects [[Object]] Array of roots of the aggregates to be destroyed.
  # @return [[Object]] Roots that were passed in.
  def destroy_all(roots)
    return roots if roots.empty?
    config = @configs.config_for(roots.first.class)
    loaded_db_objects = load_owned_from_db(roots.map(&:id), roots.first.class)
    loaded_db_objects.all_objects.each do |root|
      config.destroy(root)
    end
    roots
  end

  private

  def all_owned_objects(roots)
    traversal = Traversal.new(@configs)

    all = roots.flat_map do |root|
      owned_object_visitor = OwnedObjectVisitor.new
      traversal.accept_for_domain(root, owned_object_visitor)
      owned_object_visitor.owned_objects
    end

    all.group_by { |obj| @configs.config_for(obj.class) }
  end

  def load_from_db(ids, domain_class, only_owned=false)
    DbLoader.new(@configs, only_owned).load_from_db(ids, domain_class)
    # NaiveDbLoader.new(@configs, only_owned).load_from_db(ids, domain_class)
  end

  def load_owned_from_db(ids, domain_class)
    load_from_db(ids, domain_class, true)
  end

  def deserialize(db_objects, identity_map)
    db_objects.each do |db_object|
      # TODO: There is probably a bug here when you have something in the IdentityMap that is stale.
      identity_map.get_and_set(db_object) { @configs.config_for_db(db_object.class).deserialize(db_object) }
    end
  end

  def set_associations(db_objects, identity_map)
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
  end

  def serialize(owned_objects, mapping, loaded_db_objects)
    owned_objects.each do |config, objects|
      objects.each do |object|
        db_object = serialize_object(object, config, loaded_db_objects)
        mapping[object] = db_object
      end
    end
  end

  def serialize_object(object, config, loaded_db_objects)
    if config.serialization_required?
      attributes = config.serialize(object)
      if object.id.nil?
        config.build_db_object(attributes)
      else
        db_object = loaded_db_objects.find_by_id(object, config)
        config.set_db_object_attributes(db_object, attributes)
        db_object
      end
    else
      object
    end
  end

  def set_primary_keys(owned_objects, mapping)
    owned_objects.each do |config, objects|
      in_need_of_primary_keys = objects.find_all { |obj| obj.id.nil? }
      primary_keys = config.get_primary_keys(in_need_of_primary_keys.length)
      in_need_of_primary_keys.zip(primary_keys).each do |object, primary_key|
        mapping[object].id = primary_key
        object.id = primary_key
      end
    end
    mapping.rehash # needs to happen because setting the id on an AR::Base model changes its hash value
  end

  def set_foreign_keys(owned_objects, mapping)
    owned_objects.each do |config, objects|
      objects.each do |object|
        config.has_manys.each do |has_many_config|
          if has_many_config.owned
            children = has_many_config.get_children(object)
            children.each do |child|
              has_many_config.set_foreign_key(mapping[child], object)
            end
          end
        end

        config.has_ones.each do |has_one_config|
          if has_one_config.owned
            child = has_one_config.get_child(object)
            has_one_config.set_foreign_key(mapping[child], object)
          end
        end

        config.belongs_tos.each do |belongs_to_config|
          child = belongs_to_config.get_child(object)
          belongs_to_config.set_foreign_key(mapping[object], child)
        end
      end
    end
  end

  def save(owned_objects, mapping)
    owned_objects.each do |config, objects|
      objects.each do |object|
        config.save(mapping[object])
      end
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
class OwnedObjectVisitor
  include AggregateVisitorTemplate
  attr_reader :owned_objects

  def initialize
    @owned_objects =[]
  end

  def visit_object(object, config)
    @owned_objects << object
  end

  def continue_traversal?(association_config)
    association_config.owned
  end
end

end
