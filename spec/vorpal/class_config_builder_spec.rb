require 'integration_spec_helper'

describe ConfigBuilder do
  class Tester; end

  it 'includes the primary key in the list of fields' do
    builder = ConfigBuilder.new(Tester, {})
    config = builder.build
    # config.field
  end
end
