# Simple framelet for deserialization
#
#    class SomeDeserializer < SimpleDeserializer
#      data_attributes :site_id, :name, :category_id, :integration_key
#
#      def integration_key(old_integration_key)
#        "XX#{@data[:other_attr]}XX#{old_integration_key}XX"
#      end
#
#      def set_category_id(category_id)
#        object.category = InventoryStatusCategory.from_id(category_id)
#      end
#    end
#
# Usage:
#
#    SomeDeserializer.deserialize(object, data)
#    SomeDeserializer.new(object, data).deserialize
#
#    SomeDeserializer.deserialize_array([object1, object2, ...], [data1, data2, ...])
#
class SimpleDeserializer
  class << self
    attr_accessor :_attributes

    def inherited(base)
      base._attributes = []
    end

    def data_attributes(*attrs)
      @_attributes.concat attrs

      attrs.each do |attr|
        define_method attr do |datum|
          datum
        end unless method_defined?(attr)

        define_method "set_#{attr}" do |datum|
          object.send("#{attr}=", send(attr, datum))
        end unless method_defined?("set_#{attr}")
      end
    end

    def deserialize_array(objects, data)
      objects.zip(data).map { |obj, datum| deserialize(obj, datum) }
    end

    def deserialize(object, data)
      self.new(object, data).deserialize
    end
  end

  attr_accessor :object

  def initialize(object, data)
    @object = object
    @data = data
  end

  def deserialize
    self.class._attributes.dup.each do |name|
      next unless @data.has_key?(name)
      send("set_#{name}", @data[name])
    end
    object
  end
end
