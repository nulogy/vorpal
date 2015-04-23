module Vorpal
  class DbDriver
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

    def destroy(class_config, db_objects)
      class_config.db_class.delete_all(id: db_objects.map(&:id))
    end

    def load_by_id(class_config, ids)
      class_config.db_class.where(id: ids)
    end

    def load_by_foreign_key(class_config, id, foreign_key_info)
      arel = class_config.db_class.where(foreign_key_info.fk_column => id)
      arel = arel.where(foreign_key_info.fk_type_column => foreign_key_info.fk_type) if foreign_key_info.polymorphic?
      arel.order(:id).all
    end

    def get_primary_keys(class_config, count)
      result = execute("select nextval('#{sequence_name(class_config.db_class)}') from generate_series(1,#{count});")
      result.column_values(0).map(&:to_i)
    end

    private

    def execute(sql)
      ActiveRecord::Base.connection.execute(sql)
    end

    def sequence_name(db_class)
      "#{db_class.table_name}_id_seq"
    end
  end
end