require 'vorpal/aggregate_traversal'

module Vorpal
  # @private
  module AggregateUtils
    extend self

    def group_by_type(roots, configs)
      traversal = AggregateTraversal.new(configs)

      all = roots.flat_map do |root|
        owned_object_visitor = OwnedObjectVisitor.new
        traversal.accept(root, owned_object_visitor)
        owned_object_visitor.owned_objects
      end

      all.group_by { |obj| configs.config_for(obj.class) }
    end
  end

  # @private
  class OwnedObjectVisitor
    include AggregateVisitorTemplate
    attr_reader :owned_objects

    def initialize
      @owned_objects = []
    end

    def visit_object(object, config)
      @owned_objects << object
    end

    def continue_traversal?(association_config)
      association_config.owned
    end
  end
end