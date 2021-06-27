require 'vorpal/util/hash_initialization'
require 'vorpal/exceptions'
require 'equalizer'

module Vorpal
  module Config
    # @private
    # Object association terminology:
    # - All object associations are uni-directional
    # - The end that holds the association is the 'Parent' and the end that
    #   is referred to is the 'Child' or 'Children'
    #
    # Relational association terminology:
    # - Local end: has FK
    # - Remote end: has no FK
    #
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
  end
end
