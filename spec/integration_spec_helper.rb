require 'active_record'
require 'pg'
require 'helpers/db_helpers'
require 'helpers/codecov_helper'
require 'active_support/testing/time_helpers'
begin
  require 'activerecord-import/base'
rescue LoadError
  puts "Not using activerecord-import!"
end

DbHelpers.ensure_database_exists
DbHelpers.establish_connection

RSpec.configure do |config|
  config.include DbHelpers
  config.include ActiveSupport::Testing::TimeHelpers

  # implements `use_transactional_fixtures = true`
  config.before(:each) do
    connection = ActiveRecord::Base.connection
    connection.begin_transaction(joinable: false)
  end

  config.after(:each) do
    connection = ActiveRecord::Base.connection
    connection.rollback_transaction if connection.transaction_open?
    ActiveRecord::Base.clear_active_connections!
  end
end
