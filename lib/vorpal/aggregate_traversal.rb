module Vorpal
  # @private
  class AggregateTraversal
    def initialize(configs)
      @configs = configs
    end

    # Traversal should always begin with an object that is known to be
    # able to reach all other objects in the aggregate (like the root!)
    def accept(object, visitor, already_visited=[])
      return if object.nil?

      config = @configs.config_for(object.class)
      return if config.nil?

      return if already_visited.include?(object)
      already_visited << object

      visitor.visit_object(object, config)

      config.belongs_tos.each do |belongs_to_config|
        associate = belongs_to_config.get_associated(object)
        accept(associate, visitor, already_visited) if visitor.continue_traversal?(belongs_to_config)
      end

      config.has_ones.each do |has_one_config|
        associate = has_one_config.get_associated(object)
        accept(associate, visitor, already_visited) if visitor.continue_traversal?(has_one_config)
      end

      config.has_manys.each do |has_many_config|
        associates = has_many_config.get_associated(object)
        associates.each do |associate|
          accept(associate, visitor, already_visited) if visitor.continue_traversal?(has_many_config)
        end
      end
    end
  end

  # @private
  module AggregateVisitorTemplate
    def visit_object(object, config)
      # override me!
    end

    def continue_traversal?(association_config)
      true
    end
  end
end
