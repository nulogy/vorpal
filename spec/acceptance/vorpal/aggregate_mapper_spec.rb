require 'integration_spec_helper'
require 'vorpal'
require 'virtus'

describe 'AggregateMapper' do

  # for testing polymorphic associations
  class Bug
    include Virtus.model

    attribute :id, Integer
    attribute :name, String
    attribute :lives_on, Object
  end

  class Tree; end

  class Trunk
    include Virtus.model

    attribute :id, Integer
    attribute :length, Decimal
    attribute :bugs, Array[Bug]
    attribute :tree, Tree
  end

  class Branch
    include Virtus.model

    attribute :id, Integer
    attribute :length, Decimal
    attribute :tree, Tree
    attribute :branches, Array[Branch]
    attribute :bugs, Array[Bug]
  end

  class Fissure < ActiveRecord::Base; end
  class Swamp < ActiveRecord::Base; end

  class Tree
    include Virtus.model

    attribute :id, Integer
    attribute :name, String
    attribute :trunk, Trunk
    attribute :environment, Object
    attribute :fissures, Array[Fissure]
    attribute :branches, Array[Branch]
  end

  before(:all) do
    define_table('branches', {length: :decimal, tree_id: :integer, branch_id: :integer}, false)
    define_table('bugs', {name: :text, lives_on_id: :integer, lives_on_type: :string}, false)
    define_table('fissures', {length: :decimal, tree_id: :integer}, false)
    define_table('trees', {name: :text, trunk_id: :integer, environment_id: :integer, environment_type: :string}, false)
    define_table('trunks', {length: :decimal}, false)
    define_table('swamps', {}, false)
  end

  describe 'new records' do
    it 'saves attributes' do
      test_mapper = configure

      tree = Tree.new(name: 'backyard tree')
      test_mapper.persist(tree)

      tree_db = db_class_for(Tree, test_mapper).first
      expect(tree_db.name).to eq 'backyard tree'
    end

    it 'sets the id when first saved' do
      test_mapper = configure

      tree = Tree.new()
      test_mapper.persist(tree)

      expect(tree.id).to_not be nil

      tree_db = db_class_for(Tree, test_mapper).first
      expect(tree_db.id).to eq tree.id
    end

    it 'saves AR::Base objects' do
      test_mapper = configure

      fissure = Fissure.new(length: 21)
      tree = Tree.new(fissures: [fissure])

      test_mapper.persist(tree)

      expect(Fissure.first.length).to eq 21
    end
  end

  describe 'on error' do
    it 'nils ids of new objects' do
      db_driver = Vorpal::Driver::Postgresql.new
      test_mapper = configure(db_driver: db_driver)

      tree_db = db_class_for(Tree, test_mapper).create!

      expect(db_driver).to receive(:update).and_raise('not so good')

      fissure = Fissure.new
      tree = Tree.new(id: tree_db.id, fissures: [fissure])

      expect {
        test_mapper.persist(tree)
      }.to raise_error(Exception)

      expect(fissure.id).to eq nil
      expect(tree.id).to_not eq nil
    end
  end

  describe 'existing records' do
    it 'updates attributes' do
      test_mapper = configure

      tree = Tree.new(name: 'little tree')
      test_mapper.persist(tree)

      tree.name = 'big tree'
      test_mapper.persist(tree)

      tree_db = db_class_for(Tree, test_mapper).first
      expect(tree_db.name).to eq 'big tree'
    end

    it 'does not change the id on update' do
      test_mapper = configure

      tree = Tree.new
      test_mapper.persist(tree)

      original_id = tree.id

      tree.name = 'change it'
      test_mapper.persist(tree)

      expect(tree.id).to eq original_id
    end

    it 'does not create additional records' do
      test_mapper = configure

      tree = Tree.new
      test_mapper.persist(tree)

      tree.name = 'change it'
      test_mapper.persist(tree)

      expect(db_class_for(Tree, test_mapper).count).to eq 1
    end

    it 'removes orphans' do
      test_mapper = configure

      tree_db = db_class_for(Tree, test_mapper).create!
      db_class_for(Branch, test_mapper).create!(tree_id: tree_db.id)

      tree = Tree.new(id: tree_db.id, branches: [])

      test_mapper.persist(tree)

      expect(db_class_for(Branch, test_mapper).count).to eq 0
    end

    it 'does not remove orphans from unowned associations' do
      test_mapper = configure_unowned

      tree_db = db_class_for(Tree, test_mapper).create!
      db_class_for(Branch, test_mapper).create!(tree_id: tree_db.id)

      tree = Tree.new(id: tree_db.id, branches: [])

      test_mapper.persist(tree)

      expect(db_class_for(Branch, test_mapper).count).to eq 1
    end
  end

  it 'copies attributes to domain' do
    test_mapper = configure

    tree_db = db_class_for(Tree, test_mapper).create! name: 'tree name'
    tree = test_mapper.load_one(tree_db)

    expect(tree.id).to eq tree_db.id
    expect(tree.name).to eq 'tree name'
  end

  it 'hydrates ActiveRecord::Base associations' do
    test_mapper = configure

    tree_db = db_class_for(Tree, test_mapper).create!
    Fissure.create! length: 21, tree_id: tree_db.id

    tree = test_mapper.load_one(tree_db)

    expect(tree.fissures.first.length).to eq 21
  end

  describe 'cycles' do
    it 'persists' do
     test_mapper = configure_with_cycle

      tree = Tree.new
      long_branch = Branch.new(length: 100, tree: tree)
      tree.branches << long_branch

      test_mapper.persist(tree)

      expect(db_class_for(Tree, test_mapper).count).to eq 1
    end

    it 'hydrates' do
      test_mapper = configure_with_cycle

      tree_db = db_class_for(Tree, test_mapper).create!
      db_class_for(Branch, test_mapper).create!(length: 50, tree_id: tree_db.id)

      tree = test_mapper.load_one(tree_db)

      expect(tree).to be tree.branches.first.tree
    end
  end

  describe 'recursive associations' do
    it 'persists' do
      test_mapper = configure_recursive

      tree = Tree.new
      long_branch = Branch.new(length: 100, tree: tree)
      tree.branches << long_branch
      short_branch = Branch.new(length: 50, tree: tree)
      long_branch.branches << short_branch

      test_mapper.persist(tree)

      expect(db_class_for(Branch, test_mapper).count).to eq 2
    end

    it 'hydrates' do
      test_mapper = configure_recursive

      tree_db = db_class_for(Tree, test_mapper).create!
      long_branch = db_class_for(Branch, test_mapper).create!(length: 100, tree_id: tree_db.id)
      db_class_for(Branch, test_mapper).create!(length: 50, branch_id: long_branch.id)

      tree = test_mapper.load_one(tree_db)

      expect(tree.branches.first.branches.first.length).to eq 50
    end
  end

  describe 'belongs_to associations' do
    it 'saves attributes' do
      test_mapper = configure
      trunk = Trunk.new(length: 12)
      tree = Tree.new(trunk: trunk)

      test_mapper.persist(tree)

      trunk_db = db_class_for(Trunk, test_mapper).first
      expect(trunk_db.length).to eq 12
    end

    it 'saves foreign keys' do
      test_mapper = configure
      trunk = Trunk.new
      tree = Tree.new(trunk: trunk)

      test_mapper.persist(tree)

      tree_db = db_class_for(Tree, test_mapper).first
      expect(tree_db.trunk_id).to eq trunk.id
    end

    it 'updating does not create additional rows' do
      test_mapper = configure
      trunk = Trunk.new
      tree = Tree.new(trunk: trunk)

      test_mapper.persist(tree)

      trunk.length = 21

      expect{ test_mapper.persist(tree) }.to_not change{ db_class_for(Trunk, test_mapper).count }
    end

    it 'only saves entities that are owned' do
      test_mapper = configure_unowned

      trunk = Trunk.new
      tree = Tree.new(trunk: trunk)

      test_mapper.persist(tree)

      expect(db_class_for(Trunk, test_mapper).count).to eq 0
    end

    it 'hydrates' do
      test_mapper = configure
      trunk_db = db_class_for(Trunk, test_mapper).create!(length: 21)
      tree_db = db_class_for(Tree, test_mapper).create!(trunk_id: trunk_db.id)

      new_tree = test_mapper.load_one(tree_db)
      expect(new_tree.trunk.length).to eq 21
    end
  end

  describe 'has_many associations' do
    it 'saves' do
      test_mapper = configure
      tree = Tree.new
      tree.branches << Branch.new(length: 100)
      tree.branches << Branch.new(length: 3)

      test_mapper.persist(tree)

      branches = db_class_for(Branch, test_mapper).all
      expect(branches.size).to eq 2
      expect(branches.first.length).to eq 100
      expect(branches.second.length).to eq 3
    end

    it 'saves foreign keys' do
      test_mapper = configure
      tree = Tree.new
      tree.branches << Branch.new(length: 100)

      test_mapper.persist(tree)

      branches = db_class_for(Branch, test_mapper).all
      expect(branches.first.tree_id).to eq tree.id
    end

    it 'updates' do
      test_mapper = configure
      tree = Tree.new
      long_branch = Branch.new(length: 100)
      tree.branches << long_branch

      test_mapper.persist(tree)

      long_branch.length = 120

      test_mapper.persist(tree)

      branches = db_class_for(Branch, test_mapper).all
      expect(branches.first.length).to eq 120
    end

    it 'only saves entities that are owned' do
      test_mapper = configure_unowned

      tree = Tree.new
      long_branch = Branch.new(length: 100)
      tree.branches << long_branch

      test_mapper.persist(tree)

      expect(db_class_for(Branch, test_mapper).count).to eq 0
    end

    it 'hydrates' do
      test_mapper = configure

      tree_db = db_class_for(Tree, test_mapper).create!
      db_class_for(Branch, test_mapper).create!(length: 50, tree_id: tree_db.id)

      tree = test_mapper.load_one(tree_db)

      expect(tree.branches.first.length).to eq 50
    end
  end

  describe 'has_one associations' do
    it 'saves' do
      test_mapper = configure_has_one
      tree = Tree.new(name: 'big tree')
      trunk = Trunk.new(tree: tree)

      test_mapper.persist(trunk)

      expect(db_class_for(Tree, test_mapper).first.name).to eq 'big tree'
    end

    it 'saves foreign keys' do
      test_mapper = configure_has_one
      tree = Tree.new(name: 'big tree')
      trunk = Trunk.new(tree: tree)

      test_mapper.persist(trunk)

      expect(db_class_for(Tree, test_mapper).first.trunk_id).to eq trunk.id
    end

    it 'only saves entities that are owned' do
      test_mapper = configure_unowned_has_one
      tree = Tree.new
      trunk = Trunk.new(tree: tree)

      test_mapper.persist(trunk)

      expect(db_class_for(Tree, test_mapper).count).to eq 0
    end

    it 'hydrates' do
      test_mapper = configure_has_one

      trunk_db = db_class_for(Trunk, test_mapper).create!
      db_class_for(Tree, test_mapper).create!(name: 'big tree', trunk_id: trunk_db.id)

      trunk = test_mapper.load_one(trunk_db)

      expect(trunk.tree.name).to eq 'big tree'
    end
  end

  describe 'polymorphic associations' do
    it 'saves with has_manys' do
      test_mapper = configure_polymorphic_has_many
      trunk = Trunk.new
      branch = Branch.new
      tree = Tree.new(trunk: trunk, branches: [branch])

      trunk_bug = Bug.new
      trunk.bugs << trunk_bug
      branch_bug = Bug.new
      branch.bugs << branch_bug

      test_mapper.persist(tree)

      expect(db_class_for(Bug, test_mapper).find(trunk_bug.id).lives_on_type).to eq Trunk.name
      expect(db_class_for(Bug, test_mapper).find(branch_bug.id).lives_on_type).to eq Branch.name
    end

    it 'restores with has_manys' do
      test_mapper = configure_polymorphic_has_many

      trunk_db = db_class_for(Trunk, test_mapper).create!
      tree_db = db_class_for(Tree, test_mapper).create!(trunk_id: trunk_db.id)
      db_class_for(Bug, test_mapper).create!(name: 'trunk bug', lives_on_id: trunk_db.id, lives_on_type: Trunk.name)
      db_class_for(Bug, test_mapper).create!(name: 'not a trunk bug!', lives_on_id: trunk_db.id, lives_on_type: 'some other table')

      tree = test_mapper.load_one(tree_db)

      expect(tree.trunk.bugs.map(&:name)).to eq ['trunk bug']
    end

    it 'saves with belongs_tos' do
      test_mapper = configure_polymorphic_belongs_to

      trunk_bug = Bug.new(lives_on: Trunk.new)
      branch_bug = Bug.new(lives_on: Branch.new)

      test_mapper.persist([trunk_bug, branch_bug])

      expect(db_class_for(Bug, test_mapper).find(trunk_bug.id).lives_on_type).to eq Trunk.name
      expect(db_class_for(Bug, test_mapper).find(branch_bug.id).lives_on_type).to eq Branch.name
    end

    it 'saves associations to unowned entities via belongs_to' do
      test_mapper = configure_unowned_polymorphic_belongs_to
      trunk = Trunk.new

      trunk_bug = Bug.new(lives_on: trunk)

      test_mapper.persist(trunk_bug)

      expect(db_class_for(Bug, test_mapper).find(trunk_bug.id).lives_on_type).to eq Trunk.name
    end

    it 'restores with belongs_tos' do
      test_mapper = configure_polymorphic_belongs_to

      # makes sure that we are using the fk_type to discriminate against
      # two entities with the same primary key value
      trunk_db = db_class_for(Trunk, test_mapper).new(length: 99)
      trunk_db.id = 99
      trunk_db.save!
      trunk_bug_db = db_class_for(Bug, test_mapper).create!(lives_on_id: trunk_db.id, lives_on_type: Trunk.name)
      branch_db = db_class_for(Branch, test_mapper).new(length: 5)
      branch_db.id = 99
      branch_db.save!
      branch_bug_db = db_class_for(Bug, test_mapper).create!(lives_on_id: branch_db.id, lives_on_type: Branch.name)

      trunk_bug, branch_bug = test_mapper.load_many([trunk_bug_db, branch_bug_db])

      expect(trunk_bug.lives_on.length).to eq 99
      expect(branch_bug.lives_on.length).to eq 5
    end

    it 'restores active record objects' do
      test_mapper = configure_ar_polymorphic_belongs_to

      swamp = Swamp.create!
      tree_db = db_class_for(Tree, test_mapper).create!(environment_id: swamp.id, environment_type: Swamp.name)

      tree = test_mapper.load_one(tree_db)

      expect(tree.environment).to eq swamp
    end
  end

  describe 'arel' do
    it 'loads many' do
      test_mapper = configure

      db_class_for(Tree, test_mapper).create!
      tree_db = db_class_for(Tree, test_mapper).create!

      trees = test_mapper.query.where(id: tree_db.id).load_many

      expect(trees.map(&:id)).to eq [tree_db.id]
    end

    it 'loads one' do
      test_mapper = configure

      db_class_for(Tree, test_mapper).create!
      tree_db = db_class_for(Tree, test_mapper).create!

      trees = test_mapper.query.where(id: tree_db.id).load_one

      expect(trees.id).to eq tree_db.id
    end
  end

  describe 'load_many' do
    it 'maps given db objects' do
      test_mapper = configure

      db_class_for(Tree, test_mapper).create!
      tree_db = db_class_for(Tree, test_mapper).create!

      trees = test_mapper.load_many([tree_db])

      expect(trees.map(&:id)).to eq [tree_db.id]
    end

    it 'only returns roots' do
      test_mapper = configure

      db_class_for(Tree, test_mapper).create!
      tree_db = db_class_for(Tree, test_mapper).create!
      db_class_for(Branch, test_mapper).create!(tree_id: tree_db.id)

      trees = test_mapper.load_many([tree_db])

      expect(trees.map(&:id)).to eq [tree_db.id]
    end
  end

  describe 'destroy' do
    it 'removes the entity from the database' do
      test_mapper = configure

      tree_db = db_class_for(Tree, test_mapper).create!

      test_mapper.destroy([Tree.new(id: tree_db.id)])

      expect(db_class_for(Tree, test_mapper).count).to eq 0
    end

    it 'removes has many children from the database' do
      test_mapper = configure

      tree_db = db_class_for(Tree, test_mapper).create!
      db_class_for(Branch, test_mapper).create!(tree_id: tree_db.id)

      test_mapper.destroy(Tree.new(id: tree_db.id))

      expect(db_class_for(Branch, test_mapper).count).to eq 0
    end

    it 'removes belongs to children from the database' do
      test_mapper = configure

      trunk_db = db_class_for(Trunk, test_mapper).create!
      tree_db = db_class_for(Tree, test_mapper).create!(trunk_id: trunk_db.id)

      test_mapper.destroy(Tree.new(id: tree_db.id))

      expect(db_class_for(Trunk, test_mapper).count).to eq 0
    end

    it 'removes AR children from the database' do
      test_mapper = configure

      tree_db = db_class_for(Tree, test_mapper).create!
      Fissure.create!(tree_id: tree_db.id)

      test_mapper.destroy(Tree.new(id: tree_db.id))

      expect(Fissure.count).to eq 0
    end

    it 'leaves unowned belongs to children in the database' do
      test_mapper = configure_unowned

      trunk_db = db_class_for(Trunk, test_mapper).create!
      tree_db = db_class_for(Tree, test_mapper).create!(trunk_id: trunk_db.id)

      test_mapper.destroy(Tree.new(id: tree_db.id))

      expect(db_class_for(Trunk, test_mapper).count).to eq 1
    end

    it 'leaves unowned has many children in the database' do
      test_mapper = configure_unowned

      tree_db = db_class_for(Tree, test_mapper).create!
      db_class_for(Branch, test_mapper).create!(tree_id: tree_db.id)

      test_mapper.destroy(Tree.new(id: tree_db.id))

      expect(db_class_for(Branch, test_mapper).count).to eq 1
    end
  end

  describe 'destroy_by_id' do
    it 'removes the entity from the database' do
      test_mapper = configure

      tree_db = db_class_for(Tree, test_mapper).create!

      test_mapper.destroy_by_id([tree_db.id])

      expect(db_class_for(Tree, test_mapper).count).to eq 0
    end
  end

  describe 'non-existent values' do
    it 'load_many returns an empty array when given an empty array' do
      test_mapper = configure

      results = test_mapper.load_many([])
      expect(results).to eq []
    end

    it 'load_many throws an exception when given a nil db_object' do
      test_mapper = configure

      expect {
        test_mapper.load_many([nil])
      }.to raise_error(Vorpal::InvalidAggregateRoot, "Nil aggregate roots are not allowed.")
    end

    it 'load_one returns nil when given nil' do
      test_mapper = configure

      result = test_mapper.load_one(nil)
      expect(result).to eq nil
    end

    it 'persist ignores empty arrays' do
      test_mapper = configure

      results = test_mapper.persist([])
      expect(results).to eq []
    end

    it 'persist throws an exception when given a collection with a nil root' do
      test_mapper = configure
      expect {
        test_mapper.persist([nil])
      }.to raise_error(Vorpal::InvalidAggregateRoot, "Nil aggregate roots are not allowed.")
    end

    it 'persist throws an exception when given a nil root' do
      test_mapper = configure
      expect {
        test_mapper.persist(nil)
      }.to raise_error(Vorpal::InvalidAggregateRoot, "Nil aggregate roots are not allowed.")
    end

    it 'destroy ignores empty arrays' do
      test_mapper = configure

      results = test_mapper.destroy([])
      expect(results).to eq []
    end

    it 'destroy throws an exception when given a nil root' do
      test_mapper = configure

      expect {
        test_mapper.destroy(nil)
      }.to raise_error(Vorpal::InvalidAggregateRoot, "Nil aggregate roots are not allowed.")
    end

    it 'destroy throws an exception when given a collection with a nil root' do
      test_mapper = configure

      expect {
        test_mapper.destroy([nil])
      }.to raise_error(Vorpal::InvalidAggregateRoot, "Nil aggregate roots are not allowed.")
    end

    it 'destroy_by_id ignores empty arrays' do
      test_mapper = configure

      results = test_mapper.destroy_by_id([])
      expect(results).to eq []
    end

    it 'destroy_by_id ignores ids that do not exist' do
      test_mapper = configure

      test_mapper.destroy_by_id([99])
    end

    it 'destroy_by_id throws an exception when given a collection with a nil id' do
      test_mapper = configure

      expect {
        test_mapper.destroy_by_id([nil])
      }.to raise_error(Vorpal::InvalidPrimaryKeyValue, "Nil primary key values are not allowed.")
    end

    it 'destroy_by_id throws an exception when given a nil id' do
      test_mapper = configure

      expect {
        test_mapper.destroy_by_id(nil)
      }.to raise_error(Vorpal::InvalidPrimaryKeyValue, "Nil primary key values are not allowed.")
    end
  end

private

  def db_class_for(clazz, mapper)
    mapper.engine.mapper_for(clazz).db_class
  end

  def configure_polymorphic_has_many
    engine = Vorpal.define do
      map Tree do
        attributes :name
        has_many :branches
        belongs_to :trunk
      end

      map Trunk do
        attributes :length
        has_many :bugs, fk: :lives_on_id, fk_type: :lives_on_type
      end

      map Branch do
        attributes :length
        has_many :bugs, fk: :lives_on_id, fk_type: :lives_on_type
      end

      map Bug do
        attributes :name
      end
    end
    engine.mapper_for(Tree)
  end

  def configure_polymorphic_belongs_to
    engine = Vorpal.define do
      map Bug do
        attributes :name
        belongs_to :lives_on, fk: :lives_on_id, fk_type: :lives_on_type, child_classes: [Trunk, Branch]
      end

      map Trunk do
        attributes :length
      end

      map Branch do
        attributes :length
      end
    end
    engine.mapper_for(Bug)
  end

  def configure_ar_polymorphic_belongs_to
    engine = Vorpal.define do
      map Tree do
        attributes :name
        belongs_to :environment, owned: false, fk: :environment_id, fk_type: :environment_type, child_class: Swamp
      end

      map Swamp, to: Swamp
    end
    engine.mapper_for(Tree)
  end

  def configure_unowned_polymorphic_belongs_to
    engine = Vorpal.define do
      map Bug do
        attributes :name
        belongs_to :lives_on, owned: false, fk: :lives_on_id, fk_type: :lives_on_type, child_classes: [Trunk, Branch]
      end

      map Trunk do
        attributes :length
      end

      map Branch do
        attributes :length
      end
    end
    engine.mapper_for(Bug)
  end

  def configure_unowned
    engine = Vorpal.define do
      map Tree do
        attributes :name
        has_many :branches, owned: false
        belongs_to :trunk, owned: false
      end

      map Trunk do
        attributes :length
      end

      map Branch do
        attributes :length
      end
    end
    engine.mapper_for(Tree)
  end

  def configure_recursive
    engine = Vorpal.define do
      map Branch do
        attributes :length
        has_many :branches
      end

      map Tree do
        attributes :name
        has_many :branches
      end
    end
    engine.mapper_for(Tree)
  end

  def configure_with_cycle
    engine = Vorpal.define do
      map Branch do
        attributes :length
        belongs_to :tree
      end

      map Tree do
        attributes :name
        has_many :branches
      end
    end
    engine.mapper_for(Tree)
  end

  def configure(options={})
    engine = Vorpal.define(options) do
      map Tree do
        attributes :name
        belongs_to :trunk
        has_many :fissures
        has_many :branches
      end

      map Trunk do
        attributes :length
      end

      map Branch do
        attributes :length
      end

      map Fissure, to: Fissure
    end
    engine.mapper_for(Tree)
  end

  def configure_has_one
    engine = Vorpal.define do
      map Trunk do
        attributes :length
        has_one :tree
      end

      map Tree do
        attributes :name
      end
    end
    engine.mapper_for(Trunk)
  end

  def configure_unowned_has_one
    engine = Vorpal.define do
      map Trunk do
        attributes :length
        has_one :tree, owned: false
      end

      map Tree do
        attributes :name
      end
    end
    engine.mapper_for(Trunk)
  end
end
