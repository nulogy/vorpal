require 'unit_spec_helper'
require 'vorpal/util/string_utils'

describe Vorpal::Util::StringUtils do

  describe '.escape_class_name' do
    it 'does nothing when there are no :: in the class name' do
      expect(escape_class_name("Foo")).to eq("Foo")
    end

    it 'converts :: into __' do
      expect(escape_class_name("Foo::Bar")).to eq("Foo__Bar")
    end

    it 'converts multiple :: into __' do
      expect(escape_class_name("Foo::Bar::Baz")).to eq("Foo__Bar__Baz")
    end
  end

  private

  def escape_class_name(class_name)
    Vorpal::Util::StringUtils.escape_class_name(class_name)
  end
end
