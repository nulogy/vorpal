require 'vorpal/loaded_objects'
require 'vorpal/util/array_hash'

module Vorpal
  # Handles loading of objects from the database.
  #
  # @private
  class DbLoader
    def initialize(only_owned, db_driver)
      @only_owned = only_owned
      @db_driver = db_driver
    end

    def load_from_db(ids, config)
      db_roots = @db_driver.load_by_unique_key(config.db_class, ids, "id")
      load_from_db_objects(db_roots, config)
    end

    def load_from_db_objects(db_roots, config)
      @loaded_objects = LoadedObjects.new
      @loaded_objects.add(config, db_roots)
      @lookup_instructions = LookupInstructions.new
      explore_objects(config, db_roots)

      until @lookup_instructions.empty?
        lookup = @lookup_instructions.next_lookup
        newly_loaded_objects = lookup.load_all(@db_driver)
        unexplored_objects = @loaded_objects.add(lookup.config, newly_loaded_objects)
        explore_objects(lookup.config, unexplored_objects)
      end

      @loaded_objects
    end

    private

    def explore_objects(config, objects_to_explore)
      objects_to_explore.each do |db_object|
        config.has_manys.each do |has_many_config|
          lookup_by_fk(db_object, has_many_config) if explore_association?(has_many_config)
        end

        config.has_ones.each do |has_one_config|
          lookup_by_fk(db_object, has_one_config) if explore_association?(has_one_config)
        end

        config.belongs_tos.each do |belongs_to_config|
          lookup_by_id(db_object, belongs_to_config) if explore_association?(belongs_to_config)
        end
      end
    end

    def explore_association?(association_config)
      !@only_owned || association_config.owned == true
    end

    def lookup_by_id(db_object, belongs_to_config)
      associated_class_config = belongs_to_config.associated_class_config(db_object)
      unique_key_value = belongs_to_config.fk_value(db_object)
      unique_key_name = belongs_to_config.unique_key_name
      return if unique_key_value.nil? || @loaded_objects.already_loaded_by_unique_key?(associated_class_config, unique_key_name, unique_key_value)
      @lookup_instructions.lookup_by_unique_key(associated_class_config, unique_key_name, unique_key_value)
    end

    def lookup_by_fk(db_object, has_some_config)
      associated_class_config = has_some_config.associated_class_config
      fk_info = has_some_config.foreign_key_info
      fk_value = has_some_config.get_unique_key_value(db_object)
      @lookup_instructions.lookup_by_fk(associated_class_config, fk_info, fk_value)
    end
  end

  # @private
  class LookupInstructions
    def initialize
      @lookup_by_id = Util::ArrayHash.new
      @lookup_by_fk = Util::ArrayHash.new
    end

    def lookup_by_unique_key(config, column_name, values)
      @lookup_by_id.append([config, column_name], values)
    end

    def lookup_by_fk(config, fk_info, fk_value)
      @lookup_by_fk.append([config, fk_info], fk_value)
    end

    def next_lookup
      if @lookup_by_id.empty?
        pop_fk_lookup
      else
        pop_id_lookup
      end
    end

    def empty?
      @lookup_by_id.empty? && @lookup_by_fk.empty?
    end

    private

    def pop_id_lookup
      key, ids = @lookup_by_id.pop
      config = key.first
      column_name = key.last
      LookupById.new(config, column_name, ids)
    end

    def pop_fk_lookup
      key, fk_values = @lookup_by_fk.pop
      config = key.first
      fk_info = key.last
      LookupByFk.new(config, fk_info, fk_values)
    end
  end

  # @private
  class LookupById
    attr_reader :config
    def initialize(config, column_name, ids)
      @config = config
      @column_name = column_name
      @ids = ids
    end

    def load_all(db_driver)
      return [] if @ids.empty?
      db_driver.load_by_unique_key(@config.db_class, @ids, @column_name)
    end
  end

  # @private
  class LookupByFk
    attr_reader :config
    def initialize(config, fk_info, fk_values)
      @config = config
      @fk_info = fk_info
      @fk_values = fk_values
    end

    def load_all(db_driver)
      return [] if @fk_values.empty?
      db_driver.load_by_foreign_key(@config.db_class, @fk_values, @fk_info)
    end
  end
end
