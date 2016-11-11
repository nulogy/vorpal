module Vorpal
  class Util
    # @private
    module StringUtils
      extend self

      # Escapes the name of a class so that it can be embedded into the name
      # of another class. This means that the result should always be `#const_defined?`
      # friendly.
      def escape_class_name(class_name)
        class_name.gsub("::", "__")
      end
    end
  end
end
