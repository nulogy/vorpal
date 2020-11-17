require 'vorpal/configs'
require 'vorpal/dsl/defaults_generator'

module Vorpal
  module Dsl
  class ConfigBuilder

    # @private
    def initialize(clazz, options, db_driver)
      @domain_class = clazz
      @class_options = options
      @has_manys = []
      @has_ones = []
      @belongs_tos = []
      @attributes = []
      @primary_key = :id
      @defaults_generator = DefaultsGenerator.new(clazz, db_driver)
    end

    # Maps the given attributes to and from the domain object and the DB. Not needed
    # if a serializer and deserializer were provided.
    def attributes(*attributes)
      @attributes.concat(attributes)
    end

    def primary_key(primary_key)
      @primary_key = primary_key
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
      @has_manys << {name: name}.merge(options)
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
      @has_ones << {name: name}.merge(options)
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
      @belongs_tos << {name: name}.merge(options)
    end

    # @private
    def build
      class_config = build_class_config
      class_config.has_manys = build_has_manys
      class_config.has_ones = build_has_ones
      class_config.belongs_tos = build_belongs_tos

      class_config
    end

    # @private
    def attributes_with_id
      [@primary_key].concat @attributes
    end

    private

    def build_class_config
      Vorpal::ClassConfig.new(
        domain_class: @domain_class,
        db_class: @class_options[:to] || @defaults_generator.build_db_class(@class_options[:table_name]),
        serializer: @class_options[:serializer] || @defaults_generator.serializer(attributes_with_id),
        deserializer: @class_options[:deserializer] || @defaults_generator.deserializer(attributes_with_id),
        primary_key: @primary_key,
      )
    end

    def build_has_manys
      @has_manys.map { |options| build_has_many(options) }
    end

    def build_has_many(options)
      options[:child_class] ||= @defaults_generator.child_class(options[:name])
      options[:fk] ||= @defaults_generator.foreign_key(@domain_class.name)
      options[:owned] = options.fetch(:owned, true)
      Vorpal::HasManyConfig.new(options)
    end

    def build_has_ones
      @has_ones.map { |options| build_has_one(options) }
    end

    def build_has_one(options)
      options[:child_class] ||= @defaults_generator.child_class(options[:name])
      options[:fk] ||= @defaults_generator.foreign_key(@domain_class.name)
      options[:owned] = options.fetch(:owned, true)
      Vorpal::HasOneConfig.new(options)
    end

    def build_belongs_tos
      @belongs_tos.map { |options| build_belongs_to(options) }
    end

    def build_belongs_to(options)
      child_class = options[:child_classes] || options[:child_class] || @defaults_generator.child_class(options[:name])
      options[:child_classes] = Array(child_class)
      options[:fk] ||= @defaults_generator.foreign_key(options[:name])
      options[:owned] = options.fetch(:owned, true)
      Vorpal::BelongsToConfig.new(options)
    end
  end
  end
end
