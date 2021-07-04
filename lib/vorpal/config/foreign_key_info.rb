require 'equalizer'

module Vorpal
  module Config
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
  end
end
