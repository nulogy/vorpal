require 'vorpal/aggregate_repository'
require 'vorpal/config_builder'

module Vorpal
# Allows easy creation of {Vorpal::AggregateRepository}
# instances.
#
# ```ruby
# repository = Vorpal::Configuration.define do
#   map Tree do
#     fields :name
#     belongs_to :trunk
#     has_many :branches
#   end
#
#   map Trunk do
#     fields :length
#     has_one :tree
#   end
#
#   map Branch do
#     fields :length
#     belongs_to :tree
#   end
# end
# ```
module Configuration
  extend self

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
  # @option options [String] :table_name (Name of the domain class snake-cased and pluralized.)
  #   Name of the relational DB table.
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
