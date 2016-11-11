module Vorpal
  module Util
    # @private
    module HashInitialization
      def initialize(attrs)
        attrs.each do |k,v|
          instance_variable_set("@#{k}", v)
        end
      end
    end
  end
end
