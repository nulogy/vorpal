require 'forwardable'

module Vorpal
  module Util
    # @private
    class ArrayHash
      extend Forwardable

      def_delegators :@hash, :each, :empty?, :[]

      def initialize
        @hash = Hash.new([])
      end

      def append(key, values)
        if @hash[key].nil? || @hash[key].empty?
          @hash[key] = []
        end
        @hash[key].concat(Array(values))
      end

      def pop
        key = @hash.first.first
        values = @hash.delete(key)
        [key, values]
      end

      def values
        @hash.values.flatten
      end
    end
  end
end
