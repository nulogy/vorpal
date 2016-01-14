require 'active_record'
require 'pg'

# Change the following to reflect your database settings
ActiveRecord::Base.establish_connection(
  adapter:  'postgresql',
  host:     'localhost',
  database: 'vorpal_test',
  username: 'vorpal',
  password: 'pass',
  min_messages: 'error'
)

require 'helpers/db_helpers'

RSpec.configure do |config|
  config.include DbHelpers

  # implements `use_transactional_fixtures = true`
  config.before(:each) do
    connection = ActiveRecord::Base.connection
    if ActiveRecord::VERSION::MAJOR == 3
      # from lib/active_record/fixtures.rb
      connection.increment_open_transactions
      connection.transaction_joinable = false
      connection.begin_db_transaction
    else
      connection.begin_transaction(joinable: false)
    end
  end

  config.after(:each) do
    connection = ActiveRecord::Base.connection
    if ActiveRecord::VERSION::MAJOR == 3
      if connection.open_transactions != 0
        connection.rollback_db_transaction
        connection.decrement_open_transactions
      end
    else
      connection.rollback_transaction if connection.transaction_open?
    end
    ActiveRecord::Base.clear_active_connections!
  end
end
