require 'integration_spec_helper'
require 'vorpal'
require 'virtus'

module Performance
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
    define_table('bugs_perf', {name: :text, lives_on_id: :integer, lives_on_type: :string}, false)
    define_table('trees_perf', {name: :text, trunk_id: :integer}, false)
    define_table('trunks_perf', {length: :decimal}, false)
  end

  let(:tree_mapper) { build_mapper }

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
  #
  # Vorpal 0.1.0:
  # user     system      total        real
  # create    0.870000   0.100000   0.970000 (  1.320534)
  # update    1.820000   0.210000   2.030000 (  2.351518)
  # load      1.310000   0.010000   1.320000 (  1.394192)
  # destroy   0.930000   0.010000   0.940000 (  1.030910)
  #
  # Vorpal 1.0.0, Ruby 2.1.6, ActiveRecord 4.1.16, AR:Import 0.10.0
  #               user     system      total        real
  # create    0.980000   0.140000   1.120000 (  1.671115)
  # update    2.030000   0.250000   2.280000 (  2.748697)
  # load      1.230000   0.010000   1.240000 (  1.395219)
  # destroy   0.830000   0.010000   0.840000 (  1.042960)
  #
  # Vorpal 1.0.0, Ruby 2.3.3, ActiveRecord 4.1.16, AR:Import 0.10.0
  #               user     system      total        real
  # create    0.940000   0.120000   1.060000 (  1.579334)
  # update    1.880000   0.250000   2.130000 (  2.601979)
  # load      1.130000   0.010000   1.140000 (  1.292817)
  # destroy   0.730000   0.000000   0.730000 (  0.930980)
  #
  # Vorpal 1.0.0, Ruby 2.3.3, ActiveRecord 4.2.10, AR:Import 0.10.0
  #               user     system      total        real
  # create    1.230000   0.130000   1.360000 (  1.864400)
  # update    2.660000   0.260000   2.920000 (  3.416604)
  # load      1.310000   0.010000   1.320000 (  1.479030)
  # destroy   0.840000   0.010000   0.850000 (  1.037512)
  #
  # Vorpal 1.0.0, Ruby 2.3.3, ActiveRecord 5.0.7, AR:Import 0.13.0
  #               user     system      total        real
  # create    0.960000   0.120000   1.080000 (  1.631415)
  # update    2.810000   0.270000   3.080000 (  3.633569)
  # load      1.340000   0.010000   1.350000 (  1.510898)
  # destroy   0.900000   0.010000   0.910000 (  1.085288)
  #
  # Vorpal 1.0.0, Ruby 2.3.3, ActiveRecord 5.1.6, AR:Import 0.13.0
  # create    0.960000   0.120000   1.080000 (  1.588142)
  # update    3.030000   0.290000   3.320000 (  3.839557)
  # load      1.340000   0.010000   1.350000 (  1.509182)
  # destroy   0.950000   0.010000   0.960000 (  1.155866)
  #
  # Vorpal 1.0.0, Ruby 2.3.3, ActiveRecord 5.1.6, AR:Import 0.13.0
  # create    0.920000   0.120000   1.040000 (  1.534410)
  # update    3.010000   0.290000   3.300000 (  3.850101)
  # load      1.380000   0.010000   1.390000 (  1.561047)
  # destroy   1.050000   0.010000   1.060000 (  1.260379)
  #
  # Vorpal 1.0.1, Ruby 2.5.7, ActiveRecord 5.1.7, AR:Import 0.13.0, OSX
  #               user     system      total        real
  # create    0.865771   0.102388   0.968159 (  1.525707)
  # update    2.644134   0.206294   2.850428 (  3.318751)
  # load      1.246217   0.009570   1.255787 (  1.416289)
  # destroy   0.743522   0.002833   0.746355 (  0.951756)
  #
  # Vorpal 1.0.1, Ruby 2.5.7, ActiveRecord 5.1.7, AR:Import 0.13.0, Dockerized Test DB, OSX
  #               user     system      total        real
  # create    0.928937   0.132224   1.061161 (  5.779951)
  # update    2.980097   0.266119   3.246216 ( 12.187891)
  # load      1.254854   0.010550   1.265404 (  1.368346)
  # destroy   0.758912   0.003954   0.762866 (  0.888106)
  #
  # Vorpal 1.0.1, Ruby 2.6.3, ActiveRecord 5.2.4.1, AR:Import 0.13.0, OSX
  #               user     system      total        real
  # create    0.732053   0.096794   0.828847 (  1.301937)
  # update    2.041864   0.190059   2.231923 (  2.717304)
  # load      1.067965   0.006396   1.074361 (  1.244547)
  # destroy   0.685867   0.002530   0.688397 (  0.910923)
  #
  # Vorpal 1.0.1, Ruby 2.6.3, ActiveRecord 5.2.4.1, AR:Import 0.13.0, Dockerized Test DB, OSX
  #               user     system      total        real
  # create    0.867153   0.144517   1.011670 (  6.219567)
  # update    2.429280   0.268099   2.697379 ( 11.714242)
  # load      1.068408   0.005479   1.073887 (  1.168998)
  # destroy   0.681347   0.002968   0.684315 (  0.803671)
  #
  # Vorpal 1.0.1, Ruby 2.7.0, ActiveRecord 6.0.2, AR:Import 1.0.3, OSX
  #               user     system      total        real
  # create    0.637130   0.005220   0.642350 (  0.725564)
  # update    1.488417   0.010347   1.498764 (  1.685821)
  # load      1.209270   0.014584   1.223854 (  1.443170)
  # destroy   0.692401   0.003984   0.696385 (  0.926835)
  #
  # Vorpal 1.0.1, Ruby 2.7.0, ActiveRecord 6.0.2, AR:Import 1.0.3, Dockerized Test DB, OSX
  #               user     system      total        real
  # create    0.661741   0.008410   0.670151 (  0.785426)
  # update    1.419727   0.005630   1.425357 (  1.539234)
  # load      1.042127   0.006379   1.048506 (  1.156116)
  # destroy   0.693851   0.003333   0.697184 (  0.829565)
  #
  it 'benchmarks all operations' do
    trees = build_trees(1000)
    Benchmark.bm(7) do |x|
      x.report('create') { tree_mapper.persist(trees) }
      x.report('update') { tree_mapper.persist(trees) }
      x.report('load') { tree_mapper.query.where(id: trees.map(&:id)).load_many }
      x.report('destroy') { tree_mapper.destroy(trees) }
    end
  end

  # it 'creates aggregates quickly' do
  #   trees = build_trees(1000)
  #
  #   puts 'starting persistence benchmark'
  #   puts Benchmark.measure {
  #     tree_mapper.persist(trees)
  #   }
  # end
  #
  # it 'updates aggregates quickly' do
  #   trees = build_trees(1000)
  #
  #   tree_mapper.persist(trees)
  #
  #   puts 'starting update benchmark'
  #   puts Benchmark.measure {
  #     tree_mapper.persist(trees)
  #   }
  # end
  #
  # it 'loads aggregates quickly' do
  #   trees = build_trees(1000)
  #   tree_mapper.persist(trees)
  #   ids = trees.map(&:id)
  #
  #   puts 'starting loading benchmark'
  #   puts Benchmark.measure {
  #     tree_mapper.query.where(id: ids).load_many
  #   }
  # end
  #
  # it 'destroys aggregates quickly' do
  #   trees = build_trees(1000)
  #   tree_mapper.persist(trees)
  #
  #   puts 'starting destruction benchmark'
  #   puts Benchmark.measure {
  #     tree_mapper.destroy(trees)
  #   }
  # end

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

  def build_mapper
    engine = Vorpal.define do
      map Tree, table_name: "trees_perf" do
        attributes :name
        belongs_to :trunk
        has_many :branches
      end

      map Trunk, table_name: "trunks_perf" do
        attributes :length
        has_one :tree
        has_many :bugs, fk: :lives_on_id, fk_type: :lives_on_type
      end

      map Branch, table_name: "branches_perf" do
        attributes :length
        belongs_to :tree
        has_many :bugs, fk: :lives_on_id, fk_type: :lives_on_type
        has_many :branches
      end

      map Bug, table_name: "bugs_perf" do
        attributes :name
        belongs_to :lives_on, fk: :lives_on_id, fk_type: :lives_on_type, child_classes: [Trunk, Branch]
      end
    end
    engine.mapper_for(Tree)
  end
end
end
