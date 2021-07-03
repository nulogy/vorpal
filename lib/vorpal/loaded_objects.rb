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
      @objects_by_id = Hash.new
    end

    def add(config, objects)
      objects_to_add = objects.map do |object|
        if !already_loaded?(config, object.id)
          @objects_by_id[[config.domain_class.name, object.id]] = object
        end
      end.compact
      @objects.append(config, objects_to_add)
      objects_to_add
    end

    def find_by_primary_key(config, id)
      @objects_by_id[[config.domain_class.name, id]]
    end

    def find_by_unique_key(config, column_name, value)
      # This linear find causes a BIG slowdown in the performance tests! Need to improve with a keyed lookup.
      @objects[config].find { |object| object.send(column_name) == value }
    end

    def all_objects
      @objects_by_id.values
    end

    def already_loaded?(config, id)
      !find_by_primary_key(config, id).nil?
    end

    def already_loaded_by_unique_key?(config, column_name, id)
      !find_by_unique_key(config, column_name, id).nil?
    end
  end
end
