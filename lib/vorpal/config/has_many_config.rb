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
    class HasManyConfig
      include Util::HashInitialization
      include RemoteEndConfig

      attr_reader :name, :owned, :fk, :fk_type, :associated_class, :unique_key_name
      attr_accessor :association_config

      def get_associated(owner)
        owner.send(name)
      end

      def associate(owner, associates)
        if get_associated(owner).nil?
          owner.send("#{name}=", [])
        end
        get_associated(owner) << associates
      end

      def pretty_name
        "#{@class_config.domain_class.name} has_many :#{name}"
      end
    end
  end
end
