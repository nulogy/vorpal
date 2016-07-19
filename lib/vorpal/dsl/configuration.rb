require 'vorpal/engine'
require 'vorpal/dsl/config_builder'

module Vorpal
  module Dsl
  module Configuration

    # Configures and creates a {Engine} instance.
    #
    # @param options [Hash] Global configuration options for the engine instance.
    # @option options [Object] :db_driver (Object that will be used to interact with the DB.)
    #  Must be duck-type compatible with {DbDriver}.
    #
    # @return [Engine] Instance of the mapping engine.
    def define(options={}, &block)
      master_config = build_config(&block)
      db_driver = options.fetch(:db_driver, DbDriver.new)
      Engine.new(db_driver, master_config)
    end

    # Maps a domain class to a relational table.
    #
    # @param domain_class [Class] Type of the domain model to be mapped
    # @param options [Hash] Configure how to map the domain model
    # @option options [String] :to
    #   Class of the ActiveRecord object that will map this domain class to the DB.
    #   Optional, if one is not specified, it will be generated.
    # @option options [Object] :serializer (map the {ConfigBuilder#attributes} directly)
    #   Object that will convert the domain objects into a hash.
    #
    #   Must have a `(Hash) serialize(Object)` method.
    # @option options [Object] :deserializer (map the {ConfigBuilder#attributes} directly)
    #   Object that will set a hash of attribute_names->values onto a new domain
    #   object.
    #
    #   Must have a `(Object) deserialize(Object, Hash)` method.
    def map(domain_class, options={}, &block)
      @class_configs << build_class_config(domain_class, options, &block)
    end

    # @private
    def build_class_config(domain_class, options={}, &block)
      builder = ConfigBuilder.new(domain_class, options, DbDriver.new)
      builder.instance_exec(&block) if block_given?
      builder.build
    end

    # @private
    def build_config(&block)
      @class_configs = []
      self.instance_exec(&block)
      MasterConfig.new(@class_configs)
    end
  end
  end
end