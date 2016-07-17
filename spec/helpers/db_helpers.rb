module DbHelpers
  module_function

  CONNECTION_SETTINGS = {
    adapter: 'postgresql',
    host: 'localhost',
    database: 'vorpal_test',
    min_messages: 'error',
    # Change the following to reflect your database settings
    # username: 'vorpal',
    # password: 'pass',
  }

  def ensure_database_exists
    test_database_name = CONNECTION_SETTINGS.fetch(:database)
    if !db_exists?(test_database_name)
      db_connection.create_database(test_database_name)
    end
  end

  def db_exists?(db_name)
    ActiveRecord::Base.establish_connection(CONNECTION_SETTINGS.merge(database: 'template1'))

    return db_connection.exec_query("SELECT 1 from pg_database WHERE datname='#{db_name}';").present?
  end

  def db_connection
    ActiveRecord::Base.connection
  end

  def establish_connection
    ActiveRecord::Base.establish_connection(CONNECTION_SETTINGS)
  end

  # when you change a table's columns, set force to true to re-generate the table in the DB
  def define_table(table_name, columns, force)
    if !db_connection.table_exists?(table_name) || force
      db_connection.create_table(table_name, force: true) do |t|
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