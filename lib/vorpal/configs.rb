require 'vorpal/util/hash_initialization'
require 'vorpal/exceptions'
require 'equalizer'

module Vorpal
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
  class AssociationConfig
    include Equalizer.new(:local_class_config, :fk)

    attr_reader :local_class_config, :remote_class_configs, :fk

    # Only one of these two attributes needs to be specified
    # If one is specified, then the association is uni-directional.
    # If both are specified, then the association is bi-directional.
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
      local_end_config.associate(local_object, remote_object) if local_end_config && local_object
      remote_end_config.associate(remote_object, local_object) if remote_end_config && remote_object
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

    def set_foreign_key(local_db_object, remote_object)
      local_class_config.set_attribute(local_db_object, @fk, remote_object.try(:id))
      local_class_config.set_attribute(local_db_object, @fk_type, remote_object.class.name) if polymorphic?
    end

    def foreign_key_info(remote_class_config)
      ForeignKeyInfo.new(@fk, @fk_type, remote_class_config.domain_class.name, polymorphic?)
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
  end

  # @private
  module RemoteEndConfig
    def child_config
      association_config.local_class_config
    end

    def set_foreign_key(db_child, parent)
      association_config.set_foreign_key(db_child, parent)
    end

    def set_parent_class_config(parent_config)
      @parent_config = parent_config
    end

    def foreign_key_info
      association_config.foreign_key_info(@parent_config)
    end
  end

  # @private
  module LocalEndConfig
    def child_config(db_parent)
      association_config.remote_class_config(db_parent)
    end

    def set_foreign_key(db_parent, child)
      association_config.set_foreign_key(db_parent, child)
    end

    def fk_value(db_parent)
      db_parent.send(fk)
    end
  end

  # @private
  module ToOneConfig
    def get_child(parent)
      parent.send(name)
    end

    def associate(parent, child)
      parent.send("#{name}=", child)
    end
  end

  # @private
  module ToManyConfig
    def get_children(parent)
      parent.send(name)
    end

    def associate(parent, child)
      if get_children(parent).nil?
        parent.send("#{name}=", [])
      end
      get_children(parent) << child
    end
  end

  # @private
  class HasManyConfig
    include Util::HashInitialization
    include RemoteEndConfig
    include ToManyConfig

    attr_reader :name, :owned, :fk, :fk_type, :child_class
    attr_accessor :association_config
  end

  # @private
  class HasOneConfig
    include Util::HashInitialization
    include RemoteEndConfig
    include ToOneConfig

    attr_reader :name, :owned, :fk, :fk_type, :child_class
    attr_accessor :association_config
  end

  # @private
  class BelongsToConfig
    include Util::HashInitialization
    include LocalEndConfig
    include ToOneConfig

    attr_reader :name, :owned, :fk, :fk_type, :child_classes
    attr_accessor :association_config
  end
end
