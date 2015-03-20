require 'integration_spec_helper'
require 'vorpal'
require 'virtus'

describe 'performance' do

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

  class Tree
    include Virtus.model

    attribute :id, Integer
    attribute :name, String
    attribute :trunk, Trunk
    attribute :branches, Array[Branch]
  end

  before(:all) do
    define_table('branches_perf', {length: :decimal, tree_id: :integer, branch_id: :integer}, false)
    BranchDB = defineAr('branches_perf')

    define_table('bugs_perf', {name: :text, lives_on_id: :integer, lives_on_type: :string}, false)
    BugDB = defineAr('bugs_perf')

    define_table('trees_perf', {name: :text, trunk_id: :integer}, false)
    TreeDB = defineAr('trees_perf')

    define_table('trunks_perf', {length: :decimal}, false)
    TrunkDB = defineAr('trunks_perf')
  end

  it 'loads complex aggregates quickly' do
    test_repository = Vorpal.define do
      map Tree do
        fields :name
        belongs_to :trunk
        has_many :branches
      end

      map Trunk do
        fields :length
        has_one :tree
        has_many :bugs, fk: :lives_on_id, fk_type: :lives_on_type
      end

      map Branch do
        fields :length
        belongs_to :tree
        has_many :bugs, fk: :lives_on_id, fk_type: :lives_on_type
        has_many :branches
      end

      map Bug do
        fields :name
        belongs_to :lives_on, fk: :lives_on_id, fk_type: :lives_on_type, child_classes: [Trunk, Branch]
      end
    end

    ids = (1..1000).map do
      trunk_db = TrunkDB.create!
      tree_db = TreeDB.create!(trunk_id: trunk_db.id)
      branch_db1 = BranchDB.create!(tree_id: tree_db.id)
      branch_db2 = BranchDB.create!(tree_id: tree_db.id)
      branch_db3 = BranchDB.create!(branch_id: branch_db2.id)
      BugDB.create!(name: 'trunk bug', lives_on_id: trunk_db.id, lives_on_type: Trunk.name)
      BugDB.create!(name: 'branch bug!', lives_on_id: branch_db1.id, lives_on_type: Branch.name)
      tree_db.id
    end

    puts 'starting loading benchmark'
    puts Benchmark.measure {
        test_repository.load_all(ids, Tree)
      }
  end
end