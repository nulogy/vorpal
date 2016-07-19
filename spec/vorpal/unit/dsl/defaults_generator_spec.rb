require 'unit_spec_helper'

require 'vorpal/dsl/defaults_generator'
require 'vorpal/db_driver'

describe Vorpal::Dsl::DefaultsGenerator do
  class Tester; end
  class Author; end
  module Namespace
    class Tester; end
    class Author; end
  end

  let(:db_driver) { instance_double(Vorpal::DbDriver)}

  describe '#build_db_class' do
    it 'derives the table_name from the domain class name' do
      generator = build_generator(Tester)
      expect(db_driver).to receive(:build_db_class).with("testers")

      generator.build_db_class(nil)
    end

    it 'specifies the table_name manually' do
      generator = build_generator(Tester)
      expect(db_driver).to receive(:build_db_class).with("override")

      generator.build_db_class("override")
    end
  end

  describe '#table_name' do
    it 'namespaces the table name' do
      generator = build_generator(Namespace::Tester)

      expect(generator.table_name).to eq("namespace/testers")
    end
  end

  describe '#child_class' do
    it 'resolves the associated class' do
      generator = build_generator(Tester)
      clazz = generator.child_class("author")

      expect(clazz.name).to eq("Author")
    end

    it 'resolves the associated class in the same namespace as the owning class' do
      generator = build_generator(Namespace::Tester)
      clazz = generator.child_class("author")

      expect(clazz.name).to eq("Namespace::Author")
    end
  end

  describe '#foreign_key' do
    it 'generates a foreign key from an association name' do
      generator = build_generator(Tester)
      fk_name = generator.foreign_key("author")

      expect(fk_name).to eq("author_id")
    end

    it 'generates a foreign key from an association name regardless of the namespace of the owning class' do
      generator = build_generator(Namespace::Tester)
      fk_name = generator.foreign_key("author")

      expect(fk_name).to eq("author_id")
    end
  end

  def build_generator(domain_clazz)
    Vorpal::Dsl::DefaultsGenerator.new(domain_clazz, db_driver)
  end
end
