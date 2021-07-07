module Vorpal
  class InvalidPrimaryKeyValue < StandardError; end

  class InvalidAggregateRoot < StandardError; end

  class ConfigurationNotFound < StandardError; end

  class ConfigurationError < StandardError; end

  class InvariantViolated < StandardError; end
end
