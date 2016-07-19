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
      @defaults_generator = DefaultsGenerator.new(clazz, db_driver)
    end

    # Maps the given attributes to and from the domain object and the DB. Not needed
    # if a serializer and deserializer were provided.
    def attributes(*attributes)
      @attributes.concat(attributes)
    end

    # Defines a one-to-many association with a list of objects of the same type.
    #
    # @param name [String] Name of the attribute that will refer to the other object.
    # @param options [Hash]
    # @option options [Boolean] :owned
    # @option options [String] :fk
    # @option options [String] :fk_type
    # @option options [Class] :child_class
    def has_many(name, options={})
      @has_manys << {name: name}.merge(options)
    end

    # Defines a one-to-one association with another object where the foreign key
    # is stored on the other object.
    #
    # @param name [String] Name of the attribute that will refer to the other object.
    # @param options [Hash]
    # @option options [Boolean] :owned
    # @option options [String] :fk
    # @option options [String] :fk_type
    # @option options [Class] :child_class
    def has_one(name, options={})
      @has_ones << {name: name}.merge(options)
    end

    # Defines a one-to-one association with another object where the foreign key
    # is stored on this object.
    #
    # This association can be polymorphic. i.e.
    #
    # @param name [String] Name of the attribute that will refer to the other object.
    # @param options [Hash]
    # @option options [Boolean] :owned
    # @option options [String] :fk
    # @option options [String] :fk_type
    # @option options [Class] :child_class
    # @option options [[Class]] :child_classes
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
      [:id].concat @attributes
    end

    private

    def build_class_config
      Vorpal::ClassConfig.new(
        domain_class: @domain_class,
        db_class: @class_options[:to] || @defaults_generator.build_db_class(@class_options[:table_name]),
        serializer: @class_options[:serializer] || @defaults_generator.serializer(attributes_with_id),
        deserializer: @class_options[:deserializer] || @defaults_generator.deserializer(attributes_with_id),
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