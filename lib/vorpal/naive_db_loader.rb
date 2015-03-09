require 'vorpal/loaded_objects'

module Vorpal

class NaiveDbLoader
  def initialize(configs, only_owned)
    @configs = configs
    @traversal = Traversal.new(@configs)
    @only_owned = only_owned
  end

  def load_from_db(ids, domain_class)
    loaded_objects = LoadedObjects.new
    Array(ids).each do |id|
      config = @configs.config_for(domain_class)
      db_object = DbDriver.load_by_id(config, id)
      load_from_db_visitor = LoadFromDBVisitor.new(@only_owned, loaded_objects)
      @traversal.accept_for_db(db_object, load_from_db_visitor)
    end
    loaded_objects
  end
end

# @private
class LoadFromDBVisitor
  include AggregateVisitorTemplate

  def initialize(only_owned, loaded_objects)
    @only_owned = only_owned
    @loaded_objects = loaded_objects
  end

  def visit_object(db_object, config)
    @loaded_objects.add(config, db_object)
  end

  def continue_traversal?(association_config)
    !@only_owned || association_config.owned == true
  end
end
end