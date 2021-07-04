require 'unit_spec_helper'

require 'vorpal/loaded_objects'
require 'vorpal/config/class_config'

describe Vorpal::LoadedObjects do
  let(:config) { Vorpal::Config::ClassConfig.new(domain_class: TestObject, primary_key_type: :serial) }

  context "#add" do
    it "does not accept duplicate objects" do
      object = TestObject.new(id: 22)

      subject.add(config, [object, object])
      subject.add(config, [object])

      expect(subject.all_objects).to contain_exactly(object)
    end

    it "returns only the objects that have not yet been encountered" do
      object = TestObject.new(id: 22)

      result = subject.add(config, [object, object])

      expect(result).to eq([object])

      result = subject.add(config, [object])

      expect(result).to eq([])
    end
  end

  context "#find_by_unique_key" do
    it "locates objects by non-primary key columns" do
      object1 = TestObject.new(id: 11, unique_key: 22)
      object2 = TestObject.new(id: 33, unique_key: 44)
      subject.add(config, [object1, object2])

      result = subject.find_by_unique_key(config, "unique_key", 44)

      expect(result).to eq(object2)
    end

    it "locates objects by non-primary key columns even after new objects have been added" do
      object1 = TestObject.new(id: 11, unique_key: 22)
      subject.add(config, [object1])

      result = subject.find_by_unique_key(config, "unique_key", 22)
      expect(result).to eq(object1)

      object2 = TestObject.new(id: 33, unique_key: 44)
      subject.add(config, [object2])

      result = subject.find_by_unique_key(config, "unique_key", 44)
      expect(result).to eq(object2)
    end
  end

  class TestObject
    def initialize(id:, unique_key:nil)
      @id = id
      @unique_key = unique_key
    end

    attr_reader :id, :unique_key
  end
end
