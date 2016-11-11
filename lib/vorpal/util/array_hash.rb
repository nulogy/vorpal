module Vorpal
  module Util
    # @private
    module ArrayHash
      def add_to_hash(array_hash, key, values)
        if array_hash[key].nil? || array_hash[key].empty?
          array_hash[key] = []
        end
        array_hash[key].concat(Array(values))
      end

      def pop(array_hash)
        key = array_hash.first.first
        values = array_hash.delete(key)
        [key, values]
      end
    end
  end
end
