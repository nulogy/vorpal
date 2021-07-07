require 'vorpal/util/hash_initialization'
require 'vorpal/exceptions'
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
    module RemoteEndConfig
      def associated_class_config
        association_config.local_class_config
      end

      def set_foreign_key(db_associate, owner)
        association_config.set_foreign_key(db_associate, owner)
      end

      def set_class_config(class_config)
        @class_config = class_config
      end

      def foreign_key_info
        association_config.foreign_key_info(@class_config)
      end

      def get_unique_key_value(db_owner)
        db_owner.send(unique_key_name)
      end
    end

    # @private
    module LocalEndConfig
      def associated_class_config(db_owner)
        association_config.remote_class_config(db_owner)
      end

      def set_foreign_key(db_owner, associate)
        association_config.set_foreign_key(db_owner, associate)
      end

      def fk_value(db_owner)
        db_owner.send(fk)
      end
    end
  end
end
