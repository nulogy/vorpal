require 'vorpal/aggregate_repository'
require 'vorpal/config_builder'

module Vorpal

module Configuration

  # Configures and creates a {Vorpal::AggregateRepository} instance.
  #
  # @return [Vorpal::AggregateRepository] Repository instance.
  def define(&block)
    @class_configs = []
    self.instance_exec(&block)
    AggregateRepository.new(@class_configs)
  end

  # Maps a domain class to a relational table.
  #
  # @param domain_class [Class] Type of the domain model to be mapped
  # @param options [Hash] Configure how to map the domain model
  # @option options [String] :to (Class with the same name as the domain class with a 'DB' appended.)
  #   Class of the ActiveRecord object that will map this domain class to the DB.
  # @option options [Object] :serializer (map the {ConfigBuilder#fields} directly)
  #   Object that will convert the domain objects into a hash.
  #
  #   Must have a `(Hash) serialize(Object)` method.
  # @option options [Object] :deserializer (map the {ConfigBuilder#fields} directly)
  #   Object that will set a hash of attribute_names->values onto a new domain
  #   object.
  #
  #   Must have a `(Object) deserialize(Object, Hash)` method.
  def map(domain_class, options={}, &block)
    builder = ConfigBuilder.new(domain_class, options)
    builder.instance_exec(&block) if block_given?

    @class_configs << builder.build
  end
end
end
