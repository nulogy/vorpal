module Vorpal
  # Maps DB rows to Entities
  class IdentityMap
    def initialize
      @entities = {}
    end

    def get(db_row)
      @entities[key(db_row)]
    end

    def set(db_row, entity)
      @entities[key(db_row)] = entity
    end

    def get_and_set(db_row)
      entity = get(db_row)
      entity = yield if entity.nil?
      set(db_row, entity)
      entity
    end

    def map(key_objects)
      key_objects.map { |k| @entities[key(k)] }
    end

    private

    def key(db_row)
      return nil unless db_row
      raise "Cannot map a DB row without an id '#{db_row.inspect}' to an entity." if db_row.id.nil? # PRIMARY KEY
      raise "Cannot map a DB row without a Class with a name '#{db_row.inspect}' to an entity." if db_row.class.name.nil?
      [db_row.id, db_row.class.name] # PRIMARY KEY
    end
  end
end
