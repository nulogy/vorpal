require 'vorpal/config/foreign_key_info'
require 'equalizer'

module Vorpal
  module Config
    # @private
    # Object association terminology:
    # - All object associations are uni-directional
    # - The end that holds the association is the 'Owner' and the end that
    #   is referred to is the 'Associate' or 'Associates'
    #
    # Relational association terminology:
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

      # @return ForeignKeyInfo
      def foreign_key_info(remote_class_config)
        ForeignKeyInfo.new(@fk, @fk_type, remote_class_config.domain_class.name, polymorphic?)
      end

      def unique_key_name
        (@local_end_config || @remote_end_config).unique_key_name
      end
    end
  end
end
