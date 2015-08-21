module Vorpal
  # Interfaces between the database and Vorpal
  #
  # Currently only works for PostgreSQL.
  class DbDriver
    def initialize
      @sequence_names = {}
    end

    def insert(class_config, db_objects)
      if defined? ActiveRecord::Import
        class_config.db_class.import(db_objects, validate: false)
      else
        db_objects.each do |db_object|
          db_object.save!(validate: false)
        end
      end
    end

    def update(class_config, db_objects)
      db_objects.each do |db_object|
        db_object.save!(validate: false)
      end
    end

    def destroy(class_config, ids)
      class_config.db_class.delete_all(id: ids)
    end

    # Loads instances of the given class by primary key.
    #
    # @return [[Object]] An array of entities.
    def load_by_id(class_config, ids)
      class_config.db_class.where(id: ids)
    end

    # Loads instances of the given class whose foreign key has the given value.
    #
    # @return [[Object]] An array of entities.
    def load_by_foreign_key(class_config, id, foreign_key_info)
      arel = class_config.db_class.where(foreign_key_info.fk_column => id)
      arel = arel.where(foreign_key_info.fk_type_column => foreign_key_info.fk_type) if foreign_key_info.polymorphic?
      arel.order(:id).all
    end

    # Fetches primary key values to be used for new entities.
    #
    # @return [[Integer]] An array of unused primary keys.
    def get_primary_keys(class_config, count)
      result = execute("select nextval($1) from generate_series(1,$2);", [sequence_name(class_config), count])
      result.rows.map(&:first).map(&:to_i)
    end

    # Builds an ORM Class for accessing data in the given DB table.
    #
    # @return [Class] ActiveRecord::Base Class
    def build_db_class(table_name)
      db_class = Class.new(ActiveRecord::Base)
      db_class.table_name = table_name
      db_class
    end

    private

    def sequence_name(class_config)
      @sequence_names[class_config] ||= execute(
        "SELECT substring(column_default from '''(.*)''') FROM INFORMATION_SCHEMA.COLUMNS WHERE table_name = $1 AND column_name = 'id' LIMIT 1",
        [class_config.db_class.table_name]
      ).rows.first.first
    end

    def execute(sql, binds)
      binds = binds.map { |row| [nil, row] }
      ActiveRecord::Base.connection.exec_query(sql, 'SQL', binds)
    end
  end
end