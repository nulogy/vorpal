require 'active_record'
require 'pg' # or 'mysql2' or 'sqlite3'

# Change the following to reflect your database settings
ActiveRecord::Base.establish_connection(
  adapter:  'postgresql', # or 'mysql2' or 'sqlite3'
  host:     'localhost',
  database: 'vorpal_test',
  username: 'vorpal',
  password: 'pass',
  min_messages: 'error'
)

RSpec.configure do |config|
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # implements use_transactional_fixtures = true
  # from lib/active_record/fixtures.rb
  # works with Rails 3.2. Probably not with Rails 4
  config.before(:each) do
    connection = ActiveRecord::Base.connection
    connection.increment_open_transactions
    connection.transaction_joinable = false
    connection.begin_db_transaction
  end

  config.after(:each) do
    connection = ActiveRecord::Base.connection
    if connection.open_transactions != 0
      connection.rollback_db_transaction
      connection.decrement_open_transactions
    end
    ActiveRecord::Base.clear_active_connections!
  end
end
