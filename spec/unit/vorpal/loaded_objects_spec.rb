require 'unit_spec_helper'

require 'vorpal/loaded_objects'
require 'vorpal/configs'

describe Vorpal::LoadedObjects do
  class TestObject
    def initialize(id:)
      @id = id
    end

    attr_reader :id
  end

  it 'does not accept duplicate objects' do
    object = TestObject.new(id: 22)
    config = Vorpal::Config::ClassConfig.new(domain_class: Object, primary_key_type: :serial)

    subject.add(config, [object, object])
    subject.add(config, [object])

    expect(subject.objects.values.flatten).to contain_exactly(object)
  end
end
