require 'vorpal/util/array_hash'
require 'forwardable'

module Vorpal

  # @private
  class LoadedObjects
    include Util::ArrayHash
    extend Forwardable
    include Enumerable

    attr_reader :objects
    def_delegators :objects, :each

    def initialize
      @objects = Hash.new([])
      @objects_by_id = Hash.new
    end

    def add(config, objects)
      objects_to_add = objects.map do |object|
        if !already_loaded?(config, object.id) # PRIMARY KEY
          @objects_by_id[[config.domain_class.name, object.id]] = object # PRIMARY KEY
        end
      end
      add_to_hash(@objects, config, objects_to_add.compact)
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
