require 'integration_spec_helper'
require 'vorpal'
require 'virtus'
require 'activerecord-import/base'

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

    def add_branch(branch_options)
      branch = Branch.new(branch_options.merge(branch: self))
      branches << branch
      branch
    end
  end

  class Tree
    include Virtus.model

    attribute :id, Integer
    attribute :name, String
    attribute :trunk, Trunk
    attribute :branches, Array[Branch]

    def set_trunk(trunk)
      trunk.tree = self
      self.trunk = trunk
    end

    def add_branch(branch_options)
      branch = Branch.new(branch_options.merge(tree: self))
      branches << branch
      branch
    end
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

  let(:test_repository) { build_repository }

  # Vorpal 0.0.5:
  #               user     system      total        real
  # create    4.160000   0.440000   4.600000 (  6.071752)
  # update    7.990000   0.730000   8.720000 ( 15.281017)
  # load     10.120000   0.730000  10.850000 ( 21.087785)
  # destroy   6.090000   0.620000   6.710000 ( 12.541420)
  #
  # Vorpal 0.0.6:
  #               user     system      total        real
  # create    0.990000   0.100000   1.090000 (  1.415715)
  # update    2.240000   0.180000   2.420000 (  2.745321)
  # load      2.130000   0.020000   2.150000 (  2.223182)
  # destroy   0.930000   0.010000   0.940000 (  1.038624)
  it 'benchmarks all operations' do
    trees = build_trees(1000)
    Benchmark.bm(7) do |x|
      x.report('create') { test_repository.persist_all(trees) }
      x.report('update') { test_repository.persist_all(trees) }
      x.report('load') { ids = trees.map(&:id); test_repository.load_all(ids, Tree) }
      x.report('destroy') { test_repository.destroy_all(trees) }
    end
  end

  it 'persists aggregates quickly' do
    trees = build_trees(1000)

    puts 'starting persistence benchmark'
    puts Benchmark.measure {
      test_repository.persist_all(trees)
    }
  end

  it 'updates aggregates quickly' do
    trees = build_trees(1000)

    test_repository.persist_all(trees)

    puts 'starting update benchmark'
    puts Benchmark.measure {
      test_repository.persist_all(trees)
    }
  end

  it 'loads aggregates quickly' do
    trees = build_trees(1000)
    test_repository.persist_all(trees)
    ids = trees.map(&:id)

    puts 'starting loading benchmark'
    puts Benchmark.measure {
      test_repository.load_all(ids, Tree)
    }
  end

  it 'destroys aggregates quickly' do
    trees = build_trees(1000)
    test_repository.persist_all(trees)

    puts 'starting destruction benchmark'
    puts Benchmark.measure {
      test_repository.destroy_all(trees)
    }
  end

  def build_trees(count)
    (1..count).map do |i|
      tree = Tree.new
      trunk = Trunk.new(length: i)
      tree.set_trunk(trunk)

      branch1 = tree.add_branch(length: i * 10)
      branch2 = tree.add_branch(length: i * 20)
      branch2.add_branch(length: i * 30)

      build_bug(trunk)
      build_bug(branch1)

      tree
    end
  end

  def build_bug(bug_home)
    bug = Bug.new(lives_on: bug_home)
    bug_home.bugs = [bug]
  end

  def build_repository
    Vorpal.define do
      map Tree do
        attributes :name
        belongs_to :trunk
        has_many :branches
      end

      map Trunk do
        attributes :length
        has_one :tree
        has_many :bugs, fk: :lives_on_id, fk_type: :lives_on_type
      end

      map Branch do
        attributes :length
        belongs_to :tree
        has_many :bugs, fk: :lives_on_id, fk_type: :lives_on_type
        has_many :branches
      end

      map Bug do
        attributes :name
        belongs_to :lives_on, fk: :lives_on_id, fk_type: :lives_on_type, child_classes: [Trunk, Branch]
      end
    end
  end
end
