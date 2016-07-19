require 'simple_serializer/serializer'
require 'simple_serializer/deserializer'
require 'active_support/inflector/methods'
require 'active_support/core_ext/module/introspection'

module Vorpal
  module Dsl
  class DefaultsGenerator
    def initialize(domain_class, db_driver)
      @domain_class = domain_class
      @db_driver = db_driver
    end

    def build_db_class(user_table_name)
      @db_driver.build_db_class(user_table_name || table_name)
    end

    def table_name
      ActiveSupport::Inflector.tableize(@domain_class.name)
    end

    def serializer(attrs)
      Class.new(SimpleSerializer::Serializer) do
        hash_attributes *attrs
      end
    end

    def deserializer(attrs)
      Class.new(SimpleSerializer::Deserializer) do
        object_attributes *attrs
      end
    end

    def foreign_key(name)
      ActiveSupport::Inflector.foreign_key(name.to_s)
    end

    def child_class(association_name)
      # Module#parent comes from 'active_support/core_ext/module/introspection'
      parent_module = @domain_class.parent
      parent_module.const_get(ActiveSupport::Inflector.classify(association_name.to_s))
    end
  end
  end
end