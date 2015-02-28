module Vorpal
class DbLoader
  def initialize(configs)
    @configs = configs
  end

  def load_from_db(ids, domain_class)
    config = @configs.config_for(domain_class)
    unloaded_objects = UnloadedObjects.new
    unloaded_objects.lookup_by_id(config, ids)
    objects_to_explore = []
    loaded_objects = []

    while(!unloaded_objects.empty? || !objects_to_explore.empty?)
      new_objects = load_objects(unloaded_objects)
      loaded_objects.concat(new_objects)
      objects_to_explore.concat(new_objects)

      explore_objects(objects_to_explore, unloaded_objects)
    end

    loaded_objects
  end

  private

  def load_objects(unloaded_objects)
    lookup = unloaded_objects.next_lookup
    new_objects = lookup.load_all
    unloaded_objects.register_new_objects(lookup.config, new_objects)
    new_objects
  end

  def explore_objects(objects_to_explore, unloaded_objects)
    objects_to_explore.each do |db_object|
      config = @configs.config_for_db(db_object.class)
      config.has_manys.each do |has_many_config|
        unloaded_objects.lookup_by_fk(
          has_many_config.child_config,
          has_many_config.foreign_key_info,
          db_object.id
        )
      end

      config.has_ones.each do |has_one_config|
        unloaded_objects.lookup_by_fk(
          has_one_config.child_config,
          has_one_config.foreign_key_info,
          db_object.id
        )
      end

      config.belongs_tos.each do |belongs_to_config|
        unloaded_objects.lookup_by_id(
          belongs_to_config.child_config(db_object),
          belongs_to_config.fk_value(db_object)
        )
      end
    end
    objects_to_explore.clear
  end
end

class UnloadedObjects
  def initialize
    @lookup_by_id = {}
    @lookup_by_fk = {}
    @already_loaded = {}
  end

  def lookup_by_id(config, ids)
    ids = Array(ids) - already_loaded_ids(config)
    add_to_hash(@lookup_by_id, config, ids)
  end

  def lookup_by_fk(config, fk_info, fk_values)
    fk_values = Array(fk_values) - already_loaded_fk_values(config, fk_info)

    add_to_hash(@lookup_by_fk, [config, fk_info], fk_values)
  end

  def next_lookup
    if @lookup_by_id.empty?
      config, fk_info = @lookup_by_fk.first.first
      fk_values = @lookup_by_fk.delete([config, fk_info])
      LookupByFk.new(config, fk_info, fk_values)
    else
      config = @lookup_by_id.first.first
      ids = @lookup_by_id.delete(config)
      LookupById.new(config, ids)
    end
  end

  def register_new_objects(config, db_objects)
    add_to_hash(@already_loaded, config, db_objects)
  end

  def empty?
    @lookup_by_id.empty? && @lookup_by_fk.empty?
  end

  private

  def already_loaded_ids(config)
    (@already_loaded[config] || []).map(&:id)
  end

  def already_loaded_fk_values(config, fk_info)
    if fk_info.polymorphic?
      (@already_loaded[config] || []).
        find_all { |db_object| db_object.send(fk_info.fk_type_column) == fk_info.fk_type }.
        map(&(fk_info.fk_column.to_sym))
    else
      (@already_loaded[config] || []).map(&(fk_info.fk_column.to_sym))
    end
  end

  def add_to_hash(h, key, values)
    current_values = h[key] || []
    current_values.concat(Array(values))
    h[key] = current_values
  end
end


class LookupById
  attr_reader :config
  def initialize(config, ids)
    @config = config
    @ids = ids
  end

  def load_all
    return [] if @ids.empty?
    @config.load_all_by_id(@ids)
  end
end

class LookupByFk
  attr_reader :config
  def initialize(config, fk_info, fk_values)
    @config = config
    @fk_info = fk_info
    @fk_values = fk_values
  end

  def load_all
    return [] if @fk_values.empty?
    @config.load_by_foreign_key(@fk_values, @fk_info)
  end
end

end
