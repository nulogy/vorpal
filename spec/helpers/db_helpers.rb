module DbHelpers
  module_function

  CONNECTION_SETTINGS = {
    adapter: 'postgresql',
    host: 'localhost',
    database: 'vorpal_test',
    min_messages: 'error',
  }

  if !ENV["TRAVIS"]
    # These settings need to agree with what is in the docker-compose.yml file
    CONNECTION_SETTINGS.merge!(
      port: 55433,
      username: 'vorpal',
      password: 'pass',
    )
  end

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
  def define_table(table_name, columns, force, create_options = {})
    create_table(table_name, force: force, **create_options) do |t|
      columns.each do |name, type|
        t.send(type, name)
      end
    end
  end

  # Has the same API as the Rails create_table, except doesn't die when the
  # table already exists
  def create_table(table_name, force: nil, **options)
    return unless table_name_is_free?(table_name) || force

    db_connection.create_table(table_name, **{ force: force, **options }) do |t|
      yield t
    end
  end

  def defineAr(table_name)
    Class.new(ActiveRecord::Base) do
      self.table_name = table_name
    end
  end

  private

  def table_name_is_free?(table_name)
    if (ActiveRecord::VERSION::MAJOR == 5 && ActiveRecord::VERSION::MINOR == 1) ||
      (ActiveRecord::VERSION::MAJOR == 5 && ActiveRecord::VERSION::MINOR == 2) ||
      (ActiveRecord::VERSION::MAJOR == 6 && ActiveRecord::VERSION::MINOR == 0)
      !db_connection.data_source_exists?(table_name)
    else
      raise "ActiveRecord Version #{ActiveRecord::VERSION::STRING} is not supported!"
    end
  end
end
