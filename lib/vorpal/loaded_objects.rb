require 'vorpal/util/array_hash'
require 'forwardable'

module Vorpal

  # @private
  class LoadedObjects
    extend Forwardable
    include Enumerable

    def_delegators :@objects, :each

    def initialize
      @objects = Util::ArrayHash.new
      @cache = {}
    end

    def add(config, objects)
      objects_to_add = objects.map do |object|
        if !already_loaded?(config, object)
          add_to_cache(config, object)
        end
      end.compact
      @objects.append(config, objects_to_add)
      objects_to_add
    end

    def find_by_primary_key(config, object)
      find_by_unique_key(config, "id", object.id)
    end

    def find_by_unique_key(config, column_name, value)
      get_from_cache(config, column_name, value)
    end

    def all_objects
      @objects.values
    end

    def already_loaded_by_unique_key?(config, column_name, id)
      !find_by_unique_key(config, column_name, id).nil?
    end

    private

    def already_loaded?(config, object)
      !find_by_primary_key(config, object).nil?
    end

    # TODO: Do we have to worry about symbols vs strings for the column_name?
    def add_to_cache(config, object)
      # we take a shortcut here assuming that the cache has already been primed with the primary key column
      # because this method should always be guarded by #already_loaded?
      column_cache = @cache[config]
      column_cache.each do |column_name, unique_key_cache|
        unique_key_cache[object.send(column_name)] = object
      end
      object
    end

    def get_from_cache(config, column_name, value)
      lookup_hash(config, column_name)[value]
    end

    # lazily primes the cache
    # TODO: Do we have to worry about symbols vs strings for the column_name?
    def lookup_hash(config, column_name)
      column_cache = @cache[config]
      if column_cache.nil?
        column_cache = {}
        @cache[config] = column_cache
      end
      unique_key_cache = column_cache[column_name]
      if unique_key_cache.nil?
        unique_key_cache = {}
        column_cache[column_name] = unique_key_cache
        @objects[config].each do |object|
          unique_key_cache[object.send(column_name)] = object
        end
      end
      unique_key_cache
    end
  end
end
