require 'unit_spec_helper'

require 'vorpal/config_builder'
require 'vorpal/db_driver'

describe Vorpal::ConfigBuilder do
  class Tester; end

  let(:builder) { Vorpal::ConfigBuilder.new(Tester, {}, nil) }

  describe 'mapping attributes' do
    it 'allows the \'attributes\' method to be called multiple times' do
      builder.attributes :first
      builder.attributes :second

      expect(builder.attributes_with_id).to eq([:id, :first, :second])
    end
  end

  describe 'table name' do
    it 'is derived from the domain class name' do
      builder = Vorpal::ConfigBuilder.new(A::B::C::Test, {}, nil)
      expect(builder.table_name).to eq('a/b/c/tests')
    end

    it 'can be manually specified' do
      builder = Vorpal::ConfigBuilder.new(Tester, {table_name: 'testing123'}, nil)
      expect(builder.table_name).to eq('testing123')
    end
  end

  private

  module A
    module B
      module C
        class Test

        end
      end
    end
  end
end
