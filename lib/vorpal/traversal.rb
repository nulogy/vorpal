
# @private
class Traversal
  def initialize(configs)
    @configs = configs
  end

  def accept_for_domain(object, visitor, already_visited=[])
    return if object.nil?

    config = @configs.config_for(object.class)
    return if config.nil?

    return if already_visited.include?(object)
    already_visited << object

    visitor.visit_object(object, config)

    config.belongs_tos.each do |belongs_to_config|
      child = belongs_to_config.get_child(object)
      accept_for_domain(child, visitor, already_visited) if visitor.continue_traversal?(belongs_to_config)

      visitor.visit_belongs_to(object, child, belongs_to_config)
    end

    config.has_ones.each do |has_one_config|
      child = has_one_config.get_child(object)
      accept_for_domain(child, visitor, already_visited) if visitor.continue_traversal?(has_one_config)

      visitor.visit_has_one(object, child, has_one_config)
    end

    config.has_manys.each do |has_many_config|
      children = has_many_config.get_children(object)
      children.each do |child|
        accept_for_domain(child, visitor, already_visited) if visitor.continue_traversal?(has_many_config)
      end
      visitor.visit_has_many(object, children, has_many_config)
    end
  end

  def accept_for_db(db_object, visitor, already_visited=[])
    return if db_object.nil?

    config = @configs.config_for_db(db_object.class)
    return if config.nil?

    return if already_visited.include?(db_object)
    already_visited << db_object

    visitor.visit_object(db_object, config)

    config.belongs_tos.each do |belongs_to_config|
      child = belongs_to_config.load_child(db_object)
      accept_for_db(child, visitor, already_visited) if visitor.continue_traversal?(belongs_to_config)

      visitor.visit_belongs_to(db_object, child, belongs_to_config)
    end

    config.has_ones.each do |has_one_config|
      child = has_one_config.load_child(db_object)
      accept_for_db(child, visitor, already_visited) if visitor.continue_traversal?(has_one_config)

      visitor.visit_belongs_to(db_object, child, has_one_config)
    end

    config.has_manys.each do |has_many_config|
      children = has_many_config.load_children(db_object)
      children.each do |child|
        accept_for_db(child, visitor, already_visited) if visitor.continue_traversal?(has_many_config)
      end
      visitor.visit_has_many(db_object, children, has_many_config)
    end
  end
end

# @private
module AggregateVisitorTemplate
  def visit_object(object, config)
    # override me!
  end

  def visit_belongs_to(parent, child, belongs_to_config)
    # override me!
  end

  def visit_has_one(parent, child, has_one_config)
    # override me!
  end

  def visit_has_many(parent, children, has_many_config)
    # override me!
  end

  def continue_traversal?(association_config)
    true
  end
end