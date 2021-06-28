require 'vorpal/engine'
require 'vorpal/dsl/config_builder'
require 'vorpal/driver/postgresql'
require 'vorpal/config/main_config'

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
        @main_config = Config::MainConfig.new
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

      # Defines a one-to-many association to another type where the foreign key is stored on the associated table.
      #
      # In Object-Oriented programming, associations are *directed*. This means that they can only be
      # traversed in one direction: from the type that defines the association (the one with the
      # getter) to the type that is associated.
      #
      # @param name [String] Name of the association getter.
      # @param options [Hash]
      # @option options [Boolean] :owned (True) True if the associated type belongs to the aggregate. Changes to any object belonging to the aggregate will be persisted when the aggregate is persisted.
      # @option options [String] :fk (Association-owning class name converted to snakecase and appended with a '_id') The name of the DB column on the associated table that contains the foreign key reference to the association owner.
      # @option options [String] :fk_type The name of the DB column on the associated table that contains the association-owning class name. Only needed when the associated end is polymorphic.
      # @option options [Class] :child_class DEPRECATED. Use `associated_class` instead. The associated class.
      # @option options [Class] :associated_class (Name of the association converted to a Class) The associated class.
      def has_many(name, options={})
        @builder.has_many(name, options)
      end

      # Defines a one-to-one association to another type where the foreign key
      # is stored on the associated table.
      #
      # In Object-Oriented programming, associations are *directed*. This means that they can only be
      # traversed in one direction: from the type that defines the association (the one with the
      # getter) to the type that is associated.
      #
      # @param name [String] Name of the association getter.
      # @param options [Hash]
      # @option options [Boolean] :owned (True) True if the associated type belongs to the aggregate. Changes to any object belonging to the aggregate will be persisted when the aggregate is persisted.
      # @option options [String] :fk (Association-owning class name converted to snakecase and appended with a '_id') The name of the DB column on the associated table that contains the foreign key reference to the association owner.
      # @option options [String] :fk_type The name of the DB column on the associated table that contains the association-owning class name. Only needed when the associated end is polymorphic.
      # @option options [Class] :child_class DEPRECATED. Use `associated_class` instead. The associated class.
      # @option options [Class] :associated_class (Name of the association converted to a Class) The associated class.
      def has_one(name, options={})
        @builder.has_one(name, options)
      end

      # Defines a one-to-one association with another type where the foreign key
      # is stored on the table of the entity declaring the association.
      #
      # This association can be polymorphic. I.E. associates can be of different types.
      #
      # In Object-Oriented programming, associations are *directed*. This means that they can only be
      # traversed in one direction: from the type that defines the association (the one with the
      # getter) to the type that is associated.
      #
      # @param name [String] Name of the association getter.
      # @param options [Hash]
      # @option options [Boolean] :owned (True) True if the associated type belongs to the aggregate. Changes to any object belonging to the aggregate will be persisted when the aggregate is persisted.
      # @option options [String] :fk (Associated class name converted to snakecase and appended with a '_id') The name of the DB column on the association-owning table that contains the foreign key reference to the associated table.
      # @option options [String] :fk_type The name of the DB column on the association-owning table that contains the associated class name. Only needed when the association is polymorphic.
      # @option options [Class] :child_class DEPRECATED. Use `associated_class` instead. The associated class.
      # @option options [Class] :associated_class (Name of the association converted to a Class) The associated class.
      # @option options [[Class]] :child_classes DEPRECATED. Use `associated_classes` instead. The list of possible classes that can be associated. This is for polymorphic associations. Takes precedence over `:associated_class`.
      # @option options [[Class]] :associated_classes (Name of the association converted to a Class) The list of possible classes that can be associated. This is for polymorphic associations. Takes precedence over `:associated_class`.
      def belongs_to(name, options={})
        @builder.belongs_to(name, options)
      end
    end
  end
end
