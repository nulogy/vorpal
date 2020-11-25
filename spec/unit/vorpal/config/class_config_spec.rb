require 'unit_spec_helper'

require 'vorpal/config/class_config'

describe Vorpal::Config::ClassConfig do
  describe 'primary_key_type options' do
    it 'allows :serial' do
      class_config = described_class.new(primary_key_type: :serial)

      expect(class_config.primary_key_type).to eq(:serial)
    end

    it 'allows :uuid' do
      class_config = described_class.new(primary_key_type: :uuid)

      expect(class_config.primary_key_type).to eq(:uuid)
    end

    it 'does not allow others' do
      expect do
        described_class.new(primary_key_type: :invalid)
      end.to raise_exception("Invalid primary_key_type: 'invalid'")
    end
  end
end
