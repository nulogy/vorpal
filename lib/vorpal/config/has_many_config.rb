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
      include ToManyConfig

      attr_reader :name, :owned, :fk, :fk_type, :associated_class
      attr_accessor :association_config
    end
  end
end
