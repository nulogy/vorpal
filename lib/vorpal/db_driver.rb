module Vorpal
module DbDriver
  extend self

  def save(config, db_objects)
    db_objects.each do |db_object|
      db_object.save!
    end
  end

  def destroy(config, db_objects)
    config.db_class.delete_all(id: db_objects.map(&:id))
  end

  def load_by_id(config, ids)
    config.db_class.where(id: ids)
  end

  def load_by_foreign_key(config, id, foreign_key_info)
    arel = config.db_class.where(foreign_key_info.fk_column => id)
    arel = arel.where(foreign_key_info.fk_type_column => foreign_key_info.fk_type) if foreign_key_info.polymorphic?
    arel.order(:id).all
  end

  def get_primary_keys(config, count)
    result = ActiveRecord::Base.connection.execute("select nextval('#{sequence_name(config)}') from generate_series(1,#{count});")
    result.column_values(0).map(&:to_i)
  end

  private

  def sequence_name(config)
    "#{config.table_name}_id_seq"
  end
end
end