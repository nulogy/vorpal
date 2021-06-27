require 'vorpal/config/configs'

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
    class HasManyConfig
      include Util::HashInitialization
      include RemoteEndConfig

      attr_reader :name, :owned, :fk, :fk_type, :associated_class
      attr_accessor :association_config

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
  end
end
