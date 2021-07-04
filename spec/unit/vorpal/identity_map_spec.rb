require 'unit_spec_helper'

require 'vorpal/identity_map'

describe Vorpal::IdentityMap do
  let(:map) { Vorpal::IdentityMap.new }

  it "does not rely on the key object's implementation of hash and eql?" do
    funny1 = build_funny_entity(1)
    map.set(funny1, 'funny 1')

    funny2 = build_funny_entity(2)
    map.set(funny2, 'funny 2')

    expect(map.get(funny1)).to eq('funny 1')
  end

  it "raises an exception when the key object does not have an id set" do
    entity = build_entity(nil)

    expect { map.set(entity, 'something') }.to raise_error(/Cannot map a DB row/)
  end

  it 'raises an exception when the key object extends a class with no name (such as anonymous classes)' do
    anonymous_class = Class.new do
      attr_accessor :id

      def self.primary_key
        "id"
      end
    end

    entity = anonymous_class.new
    entity.id = 1

    expect { map.set(entity, 'something') }.to raise_error(/Cannot map a DB row/)
  end

  def build_entity(id)
    entity = Entity.new
    entity.pk = id
    entity
  end

  class Entity
    attr_accessor :pk

    def self.primary_key
      "pk"
    end
  end

  def build_funny_entity(id)
    funny1 = Funny.new
    funny1.id = id
    funny1
  end

  class Funny
    attr_accessor :id

    def self.primary_key
      "id"
    end

    def hash
      1
    end

    def eql?(other)
      true
    end
  end
end
