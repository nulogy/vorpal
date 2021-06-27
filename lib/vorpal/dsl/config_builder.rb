require 'vorpal/config/class_config'
require 'vorpal/config/has_many_config'
require 'vorpal/config/has_one_config'
require 'vorpal/config/belongs_to_config'
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

    # @private
    def attributes(*attributes)
      @attributes.concat(attributes)
    end

    # @private
    def has_many(name, options={})
      @has_manys << build_has_many({name: name}.merge(options))
    end

    # @private
    def has_one(name, options={})
      @has_ones << build_has_one({name: name}.merge(options))
    end

    # @private
    def belongs_to(name, options={})
      @belongs_tos << build_belongs_to({name: name}.merge(options))
    end

    # @private
    def build
      class_config = build_class_config
      class_config.has_manys = @has_manys
      class_config.has_ones = @has_ones
      class_config.belongs_tos = @belongs_tos

      class_config
    end

    # @private
    def attributes_with_id
      [:id].concat @attributes
    end

    private

    def build_class_config
      Vorpal::Config::ClassConfig.new(
        domain_class: @domain_class,
        db_class: @class_options[:to] || @defaults_generator.build_db_class(@class_options[:table_name]),
        serializer: @class_options[:serializer] || @defaults_generator.serializer(attributes_with_id),
        deserializer: @class_options[:deserializer] || @defaults_generator.deserializer(attributes_with_id),
        primary_key_type: @class_options[:primary_key_type] || @class_options[:id] || :serial,
      )
    end

    def build_has_many(options)
      options[:child_class] ||= @defaults_generator.child_class(options[:name])
      options[:fk] ||= @defaults_generator.foreign_key(@domain_class.name)
      options[:owned] = options.fetch(:owned, true)
      Vorpal::Config::HasManyConfig.new(options)
    end

    def build_has_one(options)
      options[:child_class] ||= @defaults_generator.child_class(options[:name])
      options[:fk] ||= @defaults_generator.foreign_key(@domain_class.name)
      options[:owned] = options.fetch(:owned, true)
      Vorpal::Config::HasOneConfig.new(options)
    end

    def build_belongs_to(options)
      child_class = options[:child_classes] || options[:child_class] || @defaults_generator.child_class(options[:name])
      options[:child_classes] = Array(child_class)
      options[:fk] ||= @defaults_generator.foreign_key(options[:name])
      options[:owned] = options.fetch(:owned, true)
      Vorpal::Config::BelongsToConfig.new(options)
    end
  end
  end
end
