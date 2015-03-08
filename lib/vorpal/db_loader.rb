module Vorpal

class DbLoader
  def initialize(configs, only_owned)
    @configs = configs
    @only_owned = only_owned
  end

  def load_from_db(ids, domain_class)
    config = @configs.config_for(domain_class)
    @loaded_objects = LoadedObjects.new
    @lookup_instructions = LookupInstructions.new
    @lookup_instructions.lookup_by_id(config, ids)

    until @lookup_instructions.empty?
      lookup = @lookup_instructions.next_lookup
      new_objects = lookup.load_all
      @loaded_objects.add(lookup.config, new_objects)
      explore_objects(new_objects)
    end

    @loaded_objects
  end

  private

  def explore_objects(objects_to_explore)
    objects_to_explore.each do |db_object|
      config = @configs.config_for_db(db_object.class)
      config.has_manys.each do |has_many_config|
        if !@only_owned || has_many_config.owned == true
          lookup_by_fk(db_object, has_many_config)
        end
      end

      config.has_ones.each do |has_one_config|
        if !@only_owned || has_one_config.owned == true
          lookup_by_fk(db_object, has_one_config)
        end
      end

      config.belongs_tos.each do |belongs_to_config|
        if !@only_owned || belongs_to_config.owned == true
          lookup_by_id(db_object, belongs_to_config)
        end
      end
    end
  end

  def lookup_by_id(db_object, belongs_to_config)
    child_config = belongs_to_config.child_config(db_object)
    id = belongs_to_config.fk_value(db_object)
    return if @loaded_objects.id_lookup_done?(child_config, id)
    @lookup_instructions.lookup_by_id(child_config, id)
  end

  def lookup_by_fk(db_object, has_many_config)
    child_config = has_many_config.child_config
    fk_info = has_many_config.foreign_key_info
    fk_value = db_object.id
    return if @loaded_objects.fk_lookup_done?(child_config, fk_info, fk_value)
    @lookup_instructions.lookup_by_fk(child_config, fk_info, fk_value)
  end
end

module ArrayHash
  def add_to_hash(h, key, values)
    if h[key].nil? || h[key].empty?
      h[key] = []
    end
    h[key].concat(Array(values))
  end
end

class LoadedObjects
  include ArrayHash

  def initialize
    @objects = Hash.new([])
  end

  def add(config, objects)
    add_to_hash(@objects, config, objects)
  end

  def find_by_id(object, config)
    @objects[config].detect { |obj| obj.id == object.id }
  end

  def loaded_ids(config)
    @objects[config].map(&:id)
  end

  def loaded_fk_values(config, fk_info)
    if fk_info.polymorphic?
      @objects[config].
        find_all { |db_object| fk_info.matches_polymorphic_type?(db_object) }.
        map(&(fk_info.fk_column.to_sym))
    else
      @objects[config].map(&(fk_info.fk_column.to_sym))
    end
  end

  def all_objects
    @objects.values.flatten
  end

  def id_lookup_done?(config, id)
    loaded_ids(config).include?(id)
  end

  def fk_lookup_done?(config, fk_info, fk_value)
    loaded_fk_values(config, fk_info).include?(fk_value)
  end
end

class LookupInstructions
  include ArrayHash
  def initialize
    @lookup_by_id = {}
    @lookup_by_fk = {}
  end

  def lookup_by_id(config, ids)
    add_to_hash(@lookup_by_id, config, Array(ids))
  end

  def lookup_by_fk(config, fk_info, fk_value)
    add_to_hash(@lookup_by_fk, [config, fk_info], fk_value)
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

  def empty?
    @lookup_by_id.empty? && @lookup_by_fk.empty?
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
