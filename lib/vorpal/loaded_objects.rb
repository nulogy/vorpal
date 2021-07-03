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
      end
      @objects.append(config, objects_to_add.compact)
    end

    def find_by_id(config, id)
      @objects_by_id[[config.domain_class.name, id]]
    end

    def all_objects
      @objects_by_id.values
    end

    def already_loaded?(config, id)
      !find_by_id(config, id).nil?
    end
  end
end
