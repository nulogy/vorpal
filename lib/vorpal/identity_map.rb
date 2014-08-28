module Vorpal
class IdentityMap
  def initialize
    @entities = {}
  end

  def get(key_object)
    @entities[key_object]
  end

  def set(key_object, object)
    @entities[key_object] = object
  end

  def get_and_set(key_object)
    object = get(key_object)
    object = yield(key_object) if object.nil?
    set(key_object, object)
    object
  end

  def map(key_objects)
    key_objects.map { |k| @entities[k] }
  end
end
end
