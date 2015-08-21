require 'unit_spec_helper'

require 'vorpal/config_builder'

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

  describe 'build_db_class' do
    it 'sets the class name' do
      driver = instance_double(Vorpal::DbDriver)
      new_class = Class.new
      expect(driver).to receive(:build_db_class).and_return(new_class)

      builder = Vorpal::ConfigBuilder.new(A::B::C::Test, {}, driver)

      builder.build_db_class

      expect(A::B::C::TestDB).to eq(new_class)
    end

    it 'does not redefine constants' do
      stub_const('A::B::C::TestDB', 1)

      builder = Vorpal::ConfigBuilder.new(A::B::C::Test, {}, nil)

      db_class = builder.build_db_class

      expect(A::B::C::TestDB).to eq(1)
      expect(db_class).to eq(1)
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
