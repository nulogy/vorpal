require 'integration_spec_helper'

require 'vorpal'

require 'virtus'

describe 'Aggregate Repository' do

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
    BranchDB = defineAr('branches')

    define_table('bugs', {name: :text, lives_on_id: :integer, lives_on_type: :string}, false)
    BugDB = defineAr('bugs')

    define_table('fissures', {length: :decimal, tree_id: :integer}, false)

    define_table('trees', {name: :text, trunk_id: :integer, environment_id: :integer, environment_type: :string}, false)
    TreeDB = defineAr('trees')

    define_table('trunks', {length: :decimal}, false)
    TrunkDB = defineAr('trunks')

    define_table('swamps', {}, false)
  end

  describe 'new records' do
    it 'saves attributes' do
      test_repository = configure

      tree = Tree.new(name: 'backyard tree')
      test_repository.persist(tree)

      tree_db = TreeDB.first
      expect(tree_db.name).to eq 'backyard tree'
    end

    it 'sets the id when first saved' do
      test_repository = configure

      tree = Tree.new()
      test_repository.persist(tree)

      expect(tree.id).to_not be nil

      tree_db = TreeDB.first
      expect(tree_db.id).to eq tree.id
    end

    it 'saves AR::Base objects' do
      test_repository = configure

      fissure = Fissure.new(length: 21)
      tree = Tree.new(fissures: [fissure])

      test_repository.persist(tree)

      expect(Fissure.first.length).to eq 21
    end
  end

  describe 'on error' do
    it 'nils ids of new objects' do
      test_repository = configure

      tree_db = TreeDB.create!

      fissure = Fissure.new
      def fissure.save!
        raise 'something bad happened!'
      end
      tree = Tree.new(id: tree_db.id, fissures: [fissure])

      expect {
        test_repository.persist(tree)
      }.to raise_error(Exception)

      expect(fissure.id).to eq nil
      expect(tree.id).to_not eq nil
    end
  end

  describe 'existing records' do
    it 'updates attributes' do
      test_repository = configure

      tree = Tree.new(name: 'little tree')
      test_repository.persist(tree)

      tree.name = 'big tree'
      test_repository.persist(tree)

      tree_db = TreeDB.first
      expect(tree_db.name).to eq 'big tree'
    end

    it 'does not change the id on update' do
      test_repository = configure

      tree = Tree.new()
      test_repository.persist(tree)

      original_id = tree.id

      tree.name = 'change it'
      test_repository.persist(tree)

      expect(tree.id).to eq original_id
    end

    it 'does not create additional records' do
      test_repository = configure

      tree = Tree.new()
      test_repository.persist(tree)

      tree.name = 'change it'
      test_repository.persist(tree)

      expect(TreeDB.count).to eq 1
    end

    it 'removes orphans' do
      test_repository = configure

      tree_db = TreeDB.create!
      BranchDB.create!(tree_id: tree_db.id)

      tree = Tree.new(id: tree_db.id, branches: [])

      test_repository.persist(tree)

      expect(BranchDB.count).to eq 0
    end

    it 'does not remove orphans from unowned associations' do
      test_repository = configure_unowned

      tree_db = TreeDB.create!
      BranchDB.create!(tree_id: tree_db.id)

      tree = Tree.new(id: tree_db.id, branches: [])

      test_repository.persist(tree)

      expect(BranchDB.count).to eq 1
    end
  end

  it 'copies attributes to domain' do
    test_repository = configure

    tree_db = TreeDB.create! name: 'tree name'
    tree = test_repository.load(tree_db.id, Tree)

    expect(tree.id).to eq tree_db.id
    expect(tree.name).to eq 'tree name'
  end

  it 'hydrates ActiveRecord::Base associations' do
    test_repository = configure

    tree_db = TreeDB.create!
    Fissure.create! length: 21, tree_id: tree_db.id

    tree = test_repository.load(tree_db.id, Tree)

    expect(tree.fissures.first.length).to eq 21
  end

  describe "cycles" do
    it 'persists' do
     test_repository = configure_with_cycle

      tree = Tree.new
      long_branch = Branch.new(length: 100, tree: tree)
      tree.branches << long_branch

      test_repository.persist(tree)

      expect(TreeDB.count).to eq 1
    end

    it 'hydrates' do
     test_repository = configure_with_cycle

      tree_db = TreeDB.create!
      BranchDB.create!(length: 50, tree_id: tree_db.id)

      tree = test_repository.load(tree_db.id, Tree)

      expect(tree).to be tree.branches.first.tree
    end
  end

  describe 'recursive associations' do
    it 'persists' do
      test_repository = configure_recursive

      tree = Tree.new
      long_branch = Branch.new(length: 100, tree: tree)
      tree.branches << long_branch
      short_branch = Branch.new(length: 50, tree: tree)
      long_branch.branches << short_branch

      test_repository.persist(tree)

      expect(BranchDB.count).to eq 2
    end

    it 'hydrates' do
      test_repository = configure_recursive

      tree_db = TreeDB.create!
      long_branch = BranchDB.create!(length: 100, tree_id: tree_db.id)
      BranchDB.create!(length: 50, branch_id: long_branch.id)

      tree = test_repository.load(tree_db.id, Tree)

      expect(tree.branches.first.branches.first.length).to eq 50
    end
  end

  describe 'belongs_to associations' do
    it 'saves attributes' do
      test_repository = configure
      trunk = Trunk.new(length: 12)
      tree = Tree.new(trunk: trunk)

      test_repository.persist(tree)

      trunk_db = TrunkDB.first
      expect(trunk_db.length).to eq 12
    end

    it 'saves foreign keys' do
      test_repository = configure
      trunk = Trunk.new()
      tree = Tree.new(trunk: trunk)

      test_repository.persist(tree)

      tree_db = TreeDB.first
      expect(tree_db.trunk_id).to eq trunk.id
    end

    it 'updating does not create additional rows' do
      test_repository = configure
      trunk = Trunk.new
      tree = Tree.new(trunk: trunk)

      test_repository.persist(tree)

      trunk.length = 21

      expect{ test_repository.persist(tree) }.to_not change{ TrunkDB.count }
    end

    it 'only saves entities that are owned' do
      test_repository = configure_unowned

      trunk = Trunk.new
      tree = Tree.new(trunk: trunk)

      test_repository.persist(tree)

      expect(TrunkDB.count).to eq 0
    end

    it 'hydrates' do
      test_repository = configure
      trunk_db = TrunkDB.create!(length: 21)
      tree_db = TreeDB.create!(trunk_id: trunk_db.id)

      new_tree = test_repository.load(tree_db.id, Tree)
      expect(new_tree.trunk.length).to eq 21
    end
  end

  describe 'has_many associations' do
    it 'saves' do
      test_repository = configure
      tree = Tree.new
      tree.branches << Branch.new(length: 100)
      tree.branches << Branch.new(length: 3)

      test_repository.persist(tree)

      branches = BranchDB.all
      expect(branches.size).to eq 2
      expect(branches.first.length).to eq 100
      expect(branches.second.length).to eq 3
    end

    it 'saves foreign keys' do
      test_repository = configure
      tree = Tree.new
      tree.branches << Branch.new(length: 100)

      test_repository.persist(tree)

      branches = BranchDB.all
      expect(branches.first.tree_id).to eq tree.id
    end

    it 'updates' do
      test_repository = configure
      tree = Tree.new
      long_branch = Branch.new(length: 100)
      tree.branches << long_branch

      test_repository.persist(tree)

      long_branch.length = 120

      test_repository.persist(tree)

      branches = BranchDB.all
      expect(branches.first.length).to eq 120
    end

    it 'only saves entities that are owned' do
      test_repository = configure_unowned

      tree = Tree.new
      long_branch = Branch.new(length: 100)
      tree.branches << long_branch

      test_repository.persist(tree)

      expect(BranchDB.count).to eq 0
    end

    it 'hydrates' do
      test_repository = configure

      tree_db = TreeDB.create!
      BranchDB.create!(length: 50, tree_id: tree_db.id)

      tree = test_repository.load(tree_db.id, Tree)

      expect(tree.branches.first.length).to eq 50
    end
  end

  describe 'has_one associations' do
    it 'saves' do
      test_repository = configure_has_one
      tree = Tree.new(name: 'big tree')
      trunk = Trunk.new(tree: tree)

      test_repository.persist(trunk)

      expect(TreeDB.first.name).to eq 'big tree'
    end

    it 'saves foreign keys' do
      test_repository = configure_has_one
      tree = Tree.new(name: 'big tree')
      trunk = Trunk.new(tree: tree)

      test_repository.persist(trunk)

      expect(TreeDB.first.trunk_id).to eq trunk.id
    end

    it 'only saves entities that are owned' do
      test_repository = configure_unowned_has_one
      tree = Tree.new
      trunk = Trunk.new(tree: tree)

      test_repository.persist(trunk)

      expect(TreeDB.count).to eq 0
    end

    it 'hydrates' do
      test_repository = configure_has_one

      trunk_db = TrunkDB.create!
      TreeDB.create!(name: 'big tree', trunk_id: trunk_db.id)

      trunk = test_repository.load(trunk_db.id, Trunk)

      expect(trunk.tree.name).to eq 'big tree'
    end
  end

  describe 'polymorphic associations' do
    it 'saves with has_manys' do
      test_repository = configure_polymorphic_has_many
      trunk = Trunk.new
      branch = Branch.new
      tree = Tree.new(trunk: trunk, branches: [branch])

      trunk_bug = Bug.new
      trunk.bugs << trunk_bug
      branch_bug = Bug.new
      branch.bugs << branch_bug

      test_repository.persist(tree)

      expect(BugDB.find(trunk_bug.id).lives_on_type).to eq Trunk.name
      expect(BugDB.find(branch_bug.id).lives_on_type).to eq Branch.name
    end

    it 'restores with has_manys' do
      test_repository = configure_polymorphic_has_many

      trunk_db = TrunkDB.create!
      BugDB.create!(name: 'trunk bug', lives_on_id: trunk_db.id, lives_on_type: Trunk.name)
      BugDB.create!(name: 'not a trunk bug!', lives_on_id: trunk_db.id, lives_on_type: 'some other table')

      trunk = test_repository.load(trunk_db.id, Trunk)

      expect(trunk.bugs.map(&:name)).to eq ['trunk bug']
    end

    it 'saves with belongs_tos' do
      test_repository = configure_polymorphic_belongs_to

      trunk_bug = Bug.new(lives_on: Trunk.new)
      branch_bug = Bug.new(lives_on: Branch.new)

      test_repository.persist_all([trunk_bug, branch_bug])

      expect(BugDB.find(trunk_bug.id).lives_on_type).to eq Trunk.name
      expect(BugDB.find(branch_bug.id).lives_on_type).to eq Branch.name
    end

    it 'saves associations to unowned entities via belongs_to' do
      test_repository = configure_unowned_polymorphic_belongs_to
      trunk = Trunk.new

      trunk_bug = Bug.new(lives_on: trunk)

      test_repository.persist(trunk_bug)

      expect(BugDB.find(trunk_bug.id).lives_on_type).to eq Trunk.name
    end

    it 'restores with belongs_tos' do
      test_repository = configure_polymorphic_belongs_to

      trunk_db = TrunkDB.create!(length: 99)
      trunk_bug_db = BugDB.create!(lives_on_id: trunk_db.id, lives_on_type: Trunk.name)
      branch_db = BranchDB.create!(length: 5)
      branch_bug_db = BugDB.create!(lives_on_id: branch_db.id, lives_on_type: Branch.name)

      trunk_bug, branch_bug = test_repository.load_all([trunk_bug_db.id, branch_bug_db.id], Bug)

      expect(trunk_bug.lives_on.length).to eq 99
      expect(branch_bug.lives_on.length).to eq 5
    end

    it 'restores active record objects' do
      test_repository = configure_ar_polymorphic_belongs_to

      swamp = Swamp.create!
      tree_db = TreeDB.create!(environment_id: swamp.id, environment_type: Swamp.name)

      tree = test_repository.load(tree_db.id, Tree)

      expect(tree.environment).to eq swamp
    end
  end

  describe 'destroy' do
    it 'removes the entity from the database' do
      test_repository = configure

      tree_db = TreeDB.create!

      test_repository.destroy_all([Tree.new(id: tree_db.id)])

      expect(TreeDB.count).to eq 0
    end

    it 'removes has many children from the database' do
      test_repository = configure

      tree_db = TreeDB.create!
      BranchDB.create!(tree_id: tree_db.id)

      test_repository.destroy(Tree.new(id: tree_db.id))

      expect(BranchDB.count).to eq 0
    end

    it 'removes belongs to children from the database' do
      test_repository = configure

      trunk_db = TrunkDB.create!
      tree_db = TreeDB.create!(trunk_id: trunk_db.id)

      test_repository.destroy(Tree.new(id: tree_db.id))

      expect(TrunkDB.count).to eq 0
    end

    it 'removes AR children from the database' do
      test_repository = configure

      tree_db = TreeDB.create!
      Fissure.create!(tree_id: tree_db.id)

      test_repository.destroy(Tree.new(id: tree_db.id))

      expect(Fissure.count).to eq 0
    end

    it 'leaves unowned belongs to children in the database' do
      test_repository = configure_unowned

      trunk_db = TrunkDB.create!
      tree_db = TreeDB.create!(trunk_id: trunk_db.id)

      test_repository.destroy(Tree.new(id: tree_db.id))

      expect(TrunkDB.count).to eq 1
    end

    it 'leaves unowned has many children in the database' do
      test_repository = configure_unowned

      tree_db = TreeDB.create!
      BranchDB.create!(tree_id: tree_db.id)

      test_repository.destroy(Tree.new(id: tree_db.id))

      expect(BranchDB.count).to eq 1
    end
  end

  # when you change a table's columns, set force to true to re-generate the table in the DB
  def define_table(table_name, columns, force)
    if !ActiveRecord::Base.connection.table_exists?(table_name) || force
      ActiveRecord::Base.connection.create_table(table_name, force: true) do |t|
        columns.each do |name, type|
          t.send(type, name)
        end
      end
    end
  end

  def defineAr(table_name)
    Class.new(ActiveRecord::Base) do
      self.table_name = table_name
    end
  end

private

  def configure_polymorphic_has_many
    Vorpal.define do
      map Tree do
        fields :name
        has_many :branches
        belongs_to :trunk
      end

      map Trunk do
        fields :length
        has_many :bugs, fk: :lives_on_id, fk_type: :lives_on_type
      end

      map Branch do
        fields :length
        has_many :bugs, fk: :lives_on_id, fk_type: :lives_on_type
      end

      map Bug do
        fields :name
      end
    end
  end

  def configure_polymorphic_belongs_to
    Vorpal.define do
      map Bug do
        fields :name
        belongs_to :lives_on, fk: :lives_on_id, fk_type: :lives_on_type, child_classes: [Trunk, Branch]
      end

      map Trunk do
        fields :length
      end

      map Branch do
        fields :length
      end
    end
  end

  def configure_ar_polymorphic_belongs_to
    Vorpal.define do
      map Tree do
        fields :name
        belongs_to :environment, owned: false, fk: :environment_id, fk_type: :environment_type, child_class: Swamp
      end

      map Swamp
    end
  end

  def configure_unowned_polymorphic_belongs_to
    Vorpal.define do
      map Bug do
        fields :name
        belongs_to :lives_on, owned: false, fk: :lives_on_id, fk_type: :lives_on_type, child_classes: [Trunk, Branch]
      end

      map Trunk do
        fields :length
      end

      map Branch do
        fields :length
      end
    end
  end

  def configure_unowned
    Vorpal.define do
      map Tree do
        fields :name
        has_many :branches, owned: false
        belongs_to :trunk, owned: false
      end

      map Trunk do
        fields :length
      end

      map Branch do
        fields :length
      end
    end
  end

  def configure_recursive
    Vorpal.define do
      map Branch do
        fields :length
        has_many :branches
      end

      map Tree do
        fields :name
        has_many :branches
      end
    end
  end

  def configure_with_cycle
    Vorpal.define do
      map Branch do
        fields :length
        belongs_to :tree
      end

      map Tree do
        fields :name
        has_many :branches
      end
    end
  end
  
  def configure
    Vorpal.define do
      map Tree do
        fields :name
        belongs_to :trunk
        has_many :fissures
        has_many :branches
      end

      map Trunk do
        fields :length
      end

      map Branch do
        fields :length
      end

      map Fissure
    end
  end

  def configure_has_one
    Vorpal.define do
      map Trunk do
        fields :length
        has_one :tree
      end

      map Tree do
        fields :name
      end
    end
  end

  def configure_unowned_has_one
    Vorpal.define do
      map Trunk do
        fields :length
        has_one :tree, owned: false
      end

      map Tree do
        fields :name
      end
    end
  end
end
