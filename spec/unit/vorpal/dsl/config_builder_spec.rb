require 'unit_spec_helper'

require 'vorpal/dsl/config_builder'

describe Vorpal::Dsl::ConfigBuilder do
  class Tester; end

  let(:builder) { Vorpal::Dsl::ConfigBuilder.new(Tester, {}, nil) }

  describe 'mapping attributes' do
    it 'allows the \'attributes\' method to be called multiple times' do
      builder.attributes :first
      builder.attributes :second

      expect(builder.attributes_with_id).to eq([:id, :first, :second])
    end
  end
end
