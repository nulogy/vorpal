module Vorpal
class IdentityMap
  def initialize
    @entities = {}
  end

  def get(key_object)
    @entities[key(key_object)]
  end

  def set(key_object, object)
    @entities[key(key_object)] = object
  end

  def get_and_set(key_object)
    object = get(key_object)
    object = yield if object.nil?
    set(key_object, object)
    object
  end

  def map(key_objects)
    key_objects.map { |k| @entities[key(k)] }
  end

  private

  def key(key_object)
    return nil unless key_object
    raise "Cannot put entity '#{key_object.inspect}' into IdentityMap without an id." if key_object.id.nil?
    [key_object.id, key_object.class.name]
  end
end
end
