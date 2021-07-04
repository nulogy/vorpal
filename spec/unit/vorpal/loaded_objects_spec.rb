require 'unit_spec_helper'

require 'vorpal/loaded_objects'
require 'vorpal/config/class_config'

describe Vorpal::LoadedObjects do
  let(:config) { Vorpal::Config::ClassConfig.new(domain_class: TestObject, primary_key_type: :serial) }

  context "#add" do
    it 'does not accept duplicate objects' do
      object = TestObject.new(id: 22)

      subject.add(config, [object, object])
      subject.add(config, [object])

      expect(subject.all_objects).to contain_exactly(object)
    end

    it 'returns only the objects that have not yet been encountered' do
      object = TestObject.new(id: 22)

      result = subject.add(config, [object, object])

      expect(result).to eq([object])

      result = subject.add(config, [object])

      expect(result).to eq([])
    end
  end

  class TestObject
    def initialize(id:)
      @id = id
    end

    attr_reader :id
  end
end
