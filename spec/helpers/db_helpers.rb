module DbHelpers
  # when you change a table's columns, set force to true to re-generate the table in the DB
  def define_table(table_name, columns, force)
    if !ActiveRecord::Base.connection.table_exists?(table_name) || force
      ActiveRecord::Base.connection.create_table(table_name, force: true) do |t|
        columns.each do |name, type|
          t.send(type, name)
        end
      end
    end
  end

  def defineAr(table_name)
    Class.new(ActiveRecord::Base) do
      self.table_name = table_name
    end
  end
end