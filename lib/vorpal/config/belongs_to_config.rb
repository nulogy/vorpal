require 'vorpal/config/configs'

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
    class BelongsToConfig
      include Util::HashInitialization
      include LocalEndConfig

      attr_reader :name, :owned, :fk, :fk_type, :associated_classes, :unique_key_name
      attr_accessor :association_config

      def get_associated(owner)
        owner.send(name)
      end

      def associate(owner, associate)
        owner.send("#{name}=", associate)
      end

      def pretty_name
        "#{association_config.local_class_config.domain_class.name} belongs_to :#{name}"
      end
    end
  end
end
