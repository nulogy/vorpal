require 'vorpal/engine'
require 'vorpal/dsl/config_builder'
require 'vorpal/driver/postgresql'

module Vorpal
  module Dsl
    # Implements the Vorpal DSL.
    #
    # ```ruby
    # engine = Vorpal.define do
    #   map Tree do
    #     attributes :name
    #     belongs_to :trunk
    #     has_many :branches
    #   end
    #
    #   map Trunk do
    #     attributes :length
    #     has_one :tree
    #   end
    #
    #   map Branch do
    #     attributes :length
    #     belongs_to :tree
    #   end
    # end
    #
    # mapper = engine.mapper_for(Tree)
    # ```
    module Configuration
      # Configures and creates a {Engine} instance.
      #
      # @param options [Hash] Global configuration options for the engine instance.
      # @option options [Object] :db_driver (Object that will be used to interact with the DB.)
      #  Must be duck-type compatible with {Postgresql}.
      #
      # @return [Engine] Instance of the mapping engine.
      def define(options={}, &block)
        @main_config = MainConfig.new
        instance_exec(&block)
        @main_config.initialize_association_configs
        db_driver = options.fetch(:db_driver, Driver::Postgresql.new)
        engine = Engine.new(db_driver, @main_config)
        @main_config = nil # make sure this MainConfig is never re-used by accident.
        engine
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
      #  @option options [Symbol] :primary_key_type [:serial, :uuid] (:serial)
      #    The type of primary key for the class. :serial for auto-incrementing integer, :uuid for a UUID
      #  @option options [Symbol] :id
      #    Same as :primary_key_type. Exists for compatibility with the Rails API.
      def map(domain_class, options={}, &block)
        class_config = build_class_config(domain_class, options, &block)
        @main_config.add_class_config(class_config)
        class_config
      end

      # @private
      def build_class_config(domain_class, options, &block)
        @builder = ConfigBuilder.new(domain_class, options, Driver::Postgresql.new)
        instance_exec(&block) if block_given?
        class_config = @builder.build
        @builder = nil # make sure this ConfigBuilder is never re-used by accident.
        class_config
      end

      # Maps the given attributes to and from the domain object and the DB. Not needed
      # if a serializer and deserializer were provided.
      def attributes(*attributes)
        @builder.attributes(*attributes)
      end

      # Defines a one-to-many association to another type where the foreign key is stored on the child.
      #
      # In Object-Oriented programming, associations are *directed*. This means that they can only be
      # traversed in one direction: from the type that defines the association (the one with the
      # getter) to the type that is associated. They end that defines the association is called the
      # 'Parent' and the end that is associated is called the 'Child'.
      #
      # @param name [String] Name of the association getter.
      # @param options [Hash]
      # @option options [Boolean] :owned (True) True if the child type belongs to the aggregate. Changes to any object belonging to the aggregate will be persisted when the aggregate is persisted.
      # @option options [String] :fk (Parent class name converted to snakecase and appended with a '_id') The name of the DB column on the child that contains the foreign key reference to the parent.
      # @option options [String] :fk_type The name of the DB column on the child that contains the parent class name. Only needed when there is an association from the child side that is polymorphic.
      # @option options [Class] :child_class (name converted to a Class) The child class.
      def has_many(name, options={})
        @builder.has_many(name, options)
      end

      # Defines a one-to-one association to another type where the foreign key
      # is stored on the child.
      #
      # In Object-Oriented programming, associations are *directed*. This means that they can only be
      # traversed in one direction: from the type that defines the association (the one with the
      # getter) to the type that is associated. They end that defines the association is called the
      # 'Parent' and the end that is associated is called the 'Child'.
      #
      # @param name [String] Name of the association getter.
      # @param options [Hash]
      # @option options [Boolean] :owned (True) True if the child type belongs to the aggregate. Changes to any object belonging to the aggregate will be persisted when the aggregate is persisted.
      # @option options [String] :fk (Parent class name converted to snakecase and appended with a '_id') The name of the DB column on the child that contains the foreign key reference to the parent.
      # @option options [String] :fk_type The name of the DB column on the child that contains the parent class name. Only needed when there is an association from the child side that is polymorphic.
      # @option options [Class] :child_class (name converted to a Class) The child class.
      def has_one(name, options={})
        @builder.has_one(name, options)
      end

      # Defines a one-to-one association with another type where the foreign key
      # is stored on the parent.
      #
      # This association can be polymorphic. I.E. children can be of different types.
      #
      # In Object-Oriented programming, associations are *directed*. This means that they can only be
      # traversed in one direction: from the type that defines the association (the one with the
      # getter) to the type that is associated. They end that defines the association is called the
      # 'Parent' and the end that is associated is called the 'Child'.
      #
      # @param name [String] Name of the association getter.
      # @param options [Hash]
      # @option options [Boolean] :owned (True) True if the child type belongs to the aggregate. Changes to any object belonging to the aggregate will be persisted when the aggregate is persisted.
      # @option options [String] :fk (Child class name converted to snakecase and appended with a '_id') The name of the DB column on the parent that contains the foreign key reference to the child.
      # @option options [String] :fk_type The name of the DB column on the parent that contains the child class name. Only needed when the association is polymorphic.
      # @option options [Class] :child_class (name converted to a Class) The child class.
      # @option options [[Class]] :child_classes The list of possible classes that can be children. This is for polymorphic associations. Takes precedence over `:child_class`.
      def belongs_to(name, options={})
        @builder.belongs_to(name, options)
      end
    end
  end
end
