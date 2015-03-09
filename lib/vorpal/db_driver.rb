module Vorpal
module DbDriver
  extend self

  def save(config, db_objects)
    db_objects.each do |db_object|
      db_object.save!
    end
  end

  def destroy(config, db_objects)
    db_objects.each do |db_object|
      db_object.destroy
    end
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