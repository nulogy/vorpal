require 'unit_spec_helper'

require 'vorpal/dsl/config_builder'
require 'vorpal/driver/postgresql'

describe Vorpal::Dsl::ConfigBuilder do
  class Tester; end

  describe 'mapping attributes' do
    it 'allows the \'attributes\' method to be called multiple times' do
      builder = new_builder
      builder.attributes :first
      builder.attributes :second

      expect(builder.attributes_with_id).to eq([:id, :first, :second])
    end
  end

  describe 'set primary key type' do
    it 'has a default of :serial' do
      builder = new_builder

      expect(builder.build.primary_key_type).to eq(:serial)
    end

    it 'reads from the :primary_key_type option' do
      builder = new_builder(primary_key_type: :uuid)

      expect(builder.build.primary_key_type).to eq(:uuid)
    end

    it 'reads from the :id option' do
      builder = new_builder(id: :uuid)

      expect(builder.build.primary_key_type).to eq(:uuid)
    end
  end

  private

  def new_builder(options = {}, db_driver = nil)
    db_driver ||= instance_double(Vorpal::Driver::Postgresql, build_db_class: nil)
    Vorpal::Dsl::ConfigBuilder.new(Tester, options, db_driver)
  end
end
