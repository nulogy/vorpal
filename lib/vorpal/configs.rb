require 'vorpal/util/hash_initialization'
require 'equalizer'

module Vorpal

# @private
class MasterConfig
  def initialize(class_configs)
    @class_configs = class_configs
    initialize_association_configs
  end

  def config_for(clazz)
    @class_configs.detect { |conf| conf.domain_class == clazz }
  end

  def config_for_db_object(db_object)
    @class_configs.detect { |conf| conf.db_class == db_object.class }
  end

  private

  def initialize_association_configs
    association_configs = {}
    @class_configs.each do |config|
      (config.has_ones + config.has_manys).each do |association_end_config|
        child_config = config_for(association_end_config.child_class)
        association_end_config.init_relational_association(child_config, config)

        association_config = build_association_config(association_configs, child_config, association_end_config.fk, association_end_config.fk_type)
        association_config.remote_end_config = association_end_config
        association_config.add_remote_class_config(config)
      end

      config.belongs_tos.each do |association_end_config|
        child_configs = association_end_config.child_classes.map(&method(:config_for))
        association_end_config.init_relational_association(child_configs, config)

        association_config = build_association_config(association_configs, config, association_end_config.fk, association_end_config.fk_type)
        association_config.local_end_config = association_end_config
        association_config.add_remote_class_config(child_configs)
      end
    end

    association_configs.values.each do |association_config|
      association_config.local_class_config.local_association_configs << association_config
    end
  end

  def build_association_config(association_configs, local_config, fk, fk_type)
    association_config = AssociationConfig.new(local_config, fk, fk_type)
    if association_configs[association_config]
      association_config = association_configs[association_config]
    else
      association_configs[association_config] = association_config
    end
    association_config
  end
end

# @private
class AssociationConfig
  include Equalizer.new(:local_class_config, :fk)

  attr_reader :local_class_config, :remote_class_configs, :fk

  # Only one of these two fields needs to be specified
  attr_accessor :local_end_config, :remote_end_config

  def initialize(local_class_config, fk, fk_type)
    @local_class_config = local_class_config
    @remote_class_configs = {}
    @fk = fk
    @fk_type = fk_type
  end

  def fk_value(local_db_object)
    local_db_object.send(fk)
  end

  def associate(local_object, remote_object)
    local_end_config.set_child(local_object, remote_object) if local_end_config && local_object
    remote_end_config.add_child(remote_object, local_object) if remote_end_config && remote_object
  end

  def add_remote_class_config(remote_class_configs)
    Array(remote_class_configs).each do |remote_class_config|
      @remote_class_configs[remote_class_config.domain_class.name] = remote_class_config
    end
  end

  def remote_class_config(local_db_object)
    if polymorphic?
      fk_type_value = local_db_object.send(@fk_type)
      @remote_class_configs[fk_type_value]
    else
      @remote_class_configs.values.first
    end
  end

  def polymorphic?
    !@fk_type.nil?
  end
end

# @private
class ClassConfig
  include Equalizer.new(:domain_class, :db_class)
  attr_reader :serializer, :deserializer, :domain_class, :db_class, :local_association_configs
  attr_accessor :has_manys, :belongs_tos, :has_ones

  def initialize(attrs)
    @has_manys = []
    @belongs_tos = []
    @has_ones = []
    @local_association_configs = []

    attrs.each do |k,v|
      instance_variable_set("@#{k}", v)
    end
  end

  def build_db_object(attributes)
    db_class.new(attributes)
  end

  def set_db_object_attributes(db_object, attributes)
    db_object.attributes = attributes
  end

  def get_db_object_attributes(db_object)
    db_object.attributes.symbolize_keys
  end

  def serialization_required?
    !(domain_class < ActiveRecord::Base)
  end

  def serialize(object)
    serializer.serialize(object)
  end

  def deserialize(db_object)
    attributes = get_db_object_attributes(db_object)
    serialization_required? ? deserializer.deserialize(domain_class.new, attributes) : db_object
  end

  def set_field(db_object, field, value)
    db_object.send("#{field}=", value)
  end

  def get_field(db_object, field)
    db_object.send(field)
  end
end

# @private
class ForeignKeyInfo
  include Equalizer.new(:fk_column, :fk_type_column, :fk_type)

  attr_reader :fk_column, :fk_type_column, :fk_type, :polymorphic

  def initialize(fk_column, fk_type_column, fk_type, polymorphic)
    @fk_column = fk_column
    @fk_type_column = fk_type_column
    @fk_type = fk_type
    @polymorphic = polymorphic
  end

  def polymorphic?
    @polymorphic
  end

  def matches_polymorphic_type?(db_object)
    db_object.send(fk_type_column) == fk_type
  end
end

# @private
# Object associations:
# - All object associations are uni-directional
# - The end that holds the association is the 'Parent' and the end that
#   is referred to is the 'Child' or 'Children'
#
# Relational associations:
# - Local end: has FK
# - Remote end: has no FK
#
class RelationalAssociation
  include HashInitialization
  attr_reader :fk, :fk_type, :local_config, :remote_configs

  # Can't pass in a remote db model for last param because when saving we only have
  # a db model if the model is part of the aggregate and not just referenced by the
  # aggregate
  def set_foreign_key(local_db_model, remote_model)
    local_config.set_field(local_db_model, fk, remote_model.try(:id))
    local_config.set_field(local_db_model, fk_type, remote_model.class.name) if polymorphic?
  end

  def remote_config_for_local_db_object(local_db_model)
    class_name = local_config.get_field(local_db_model, fk_type)
    remote_configs.detect { |config| config.domain_class.name == class_name }
  end

  def polymorphic?
    !fk_type.nil?
  end

  def foreign_key_info(remote_class_config)
    ForeignKeyInfo.new(fk, fk_type, remote_class_config.domain_class.name, polymorphic?)
  end
end

# @private
class HasManyConfig
  include HashInitialization
  attr_reader :name, :owned, :fk, :fk_type, :child_class

  def init_relational_association(child_config, parent_config)
    @parent_config = parent_config
    @relational_association = RelationalAssociation.new(fk: fk, fk_type: fk_type, local_config: child_config, remote_configs: [parent_config])
  end

  def get_children(parent)
    parent.send(name)
  end

  def add_child(parent, child)
    if get_children(parent).nil?
      parent.send("#{name}=", [])
    end
    get_children(parent) << child
  end

  def set_foreign_key(db_child, parent)
    @relational_association.set_foreign_key(db_child, parent)
  end

  def associated?(db_parent, db_child)
    return false if child_config.db_class != db_child.class
    db_child.send(fk) == db_parent.id
  end

  def child_config
    @relational_association.local_config
  end

  def foreign_key_info
    @relational_association.foreign_key_info(@parent_config)
  end
end

# @private
  class BelongsToConfig
    include HashInitialization
    attr_reader :name, :owned, :fk, :fk_type, :child_classes

    def init_relational_association(child_configs, parent_config)
      @relational_association = RelationalAssociation.new(fk: fk, fk_type: fk_type, local_config: parent_config, remote_configs: child_configs)
    end

    def get_child(parent)
      parent.send(name)
    end

    def set_child(parent, child)
      parent.send("#{name}=", child)
    end

    def set_foreign_key(db_parent, child)
      @relational_association.set_foreign_key(db_parent, child)
    end

    def child_config(db_parent)
      if @relational_association.polymorphic?
        @relational_association.remote_config_for_local_db_object(db_parent)
      else
        @relational_association.remote_configs.first
      end
    end

    def fk_value(db_parent)
      db_parent.send(fk)
    end
  end

# @private
class HasOneConfig
  include HashInitialization
  attr_reader :name, :owned, :fk, :fk_type, :child_class

  def init_relational_association(child_config, parent_config)
    @parent_config = parent_config
    @relational_association = RelationalAssociation.new(fk: fk, fk_type: fk_type, local_config: child_config, remote_configs: [parent_config])
  end

  def get_child(parent)
    parent.send(name)
  end

  def add_child(parent, child)
    parent.send("#{name}=", child)
  end

  def set_foreign_key(db_child, parent)
    @relational_association.set_foreign_key(db_child, parent)
  end

  def child_config
    @relational_association.local_config
  end

  def foreign_key_info
    @relational_association.foreign_key_info(@parent_config)
  end
end

end
