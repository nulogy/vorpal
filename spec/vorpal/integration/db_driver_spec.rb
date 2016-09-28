require 'unit_spec_helper'
require 'vorpal'
require 'virtus'
require 'active_record'

describe Vorpal::DbDriver do
  describe '#build_db_class' do
    let(:db_class) { subject.build_db_class('trees') }

    it 'generates a vald class name so that rails auto-reloading works' do
      expect {Vorpal.const_defined?(db_class.name)}.to_not raise_error
    end

    it 'does not let the user access the generated class' do
      expect{Vorpal.const_get(db_class.name)}.to raise_error(NameError)
    end
  end
end
