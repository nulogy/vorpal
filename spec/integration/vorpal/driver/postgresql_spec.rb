# frozen_string_literal: true

require 'integration_spec_helper'
require 'vorpal'

describe Vorpal::Driver::Postgresql do
  before(:all) do
    create_table('actors') do |t|
      t.string :name
      t.timestamps
      t.index :name, unique: true
    end
  end

  let(:db_driver) { Vorpal::Driver::Postgresql.new }

  describe '#build_db_class' do
    let(:db_class) { subject.build_db_class(PostgresDriverSpec::Foo, 'example') }

    it 'generates a valid class name so that rails auto-reloading works' do
      expect { Vorpal.const_defined?(db_class.name) }.to_not raise_error
    end

    it 'does not let the user access the generated class' do
      expect { Vorpal.const_get(db_class.name) }.to raise_error(NameError)
    end

    it 'isolates two POROs that map to the same db table' do
      db_class1 = build_db_class(PostgresDriverSpec::Foo)
      db_class2 = build_db_class(PostgresDriverSpec::Bar)

      expect(db_class1).to_not eq(db_class2)
      expect(db_class1.name).to_not eq(db_class2.name)
    end

    it 'uses the model class name to make the generated AR::Base class name unique' do
      db_class = build_db_class(PostgresDriverSpec::Foo)

      expect(db_class.name).to match('PostgresDriverSpec__Foo')
    end
  end

  describe '#insert' do
    it 'sets the created_at column' do
      nick_cage = build_actor(created_at: nil)

      db_driver.insert(PostgresDriverSpec::Actor, [nick_cage])

      nick_cage.reload
      expect(nick_cage.created_at).to_not be_nil
    end

    it 'blows up if a duplicate PK is used' do
      nick_cage =  build_actor(id: 1, name: 'Nicholas Cage')
      will_farrell = build_actor(id: 1, name: 'William Farrell')

      expect do
        db_driver.insert(PostgresDriverSpec::Actor, [nick_cage, will_farrell])
      end.to raise_exception(ActiveRecord::RecordNotUnique)
    end

    it 'blows up if a non-PK uniqueness constraint is violated' do
      nick_cage = build_actor(id: 1, name: 'Nicholas Cage')
      nick_cage2 = build_actor(id: 2, name: 'Nicholas Cage')

      expect do
        db_driver.insert(PostgresDriverSpec::Actor, [nick_cage, nick_cage2])
      end.to raise_exception(ActiveRecord::RecordNotUnique)
    end
  end

  describe '#update' do
    it 'sets the updated_at column' do
      actor = create_actor

      Timecop.freeze(Time.local(2000, 1, 1)) do
        db_driver.update(PostgresDriverSpec::Actor, [actor])
      end

      actor.reload
      expect(actor.updated_at).to eq(Time.local(2000, 1, 1))
    end

    it 'leaves the created_at column alone' do
      actor = create_actor
      old_created_at = actor.created_at

      db_driver.update(PostgresDriverSpec::Actor, [actor])

      actor.reload
      expect(actor.created_at).to eq(old_created_at)
    end

    it 'blows up if a non-PK uniqueness constraint is violated' do
      nick_cage =  create_actor(id: 1, name: 'Nicholas Cage')
      nick_cage2 = create_actor(id: 2)
      nick_cage2.name = nick_cage.name

      expect do
        db_driver.update(PostgresDriverSpec::Actor, [nick_cage, nick_cage2])
      end.to raise_exception(ActiveRecord::RecordNotUnique)
    end
  end

  private

  module PostgresDriverSpec
    class Foo; end
    class Bar; end
    class Actor < ActiveRecord::Base; end
  end

  def create_actor(id: 1, name: 'actor 1', **options)
    actor = build_actor(**{ id: id, name: name, **options })
    actor.save!
    actor
  end

  def build_actor(id: 1, name: 'actor 1', **options)
    PostgresDriverSpec::Actor.new(**{ id: id, name: name, **options })
  end

  def build_db_class(clazz)
    db_driver.build_db_class(clazz, 'example')
  end
end
