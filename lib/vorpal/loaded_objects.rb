require 'vorpal/util/array_hash'

module Vorpal

# @private
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
end
