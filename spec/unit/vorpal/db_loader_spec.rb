require 'unit_spec_helper'
require 'vorpal'

describe Vorpal::DbLoader do

  class Post; end

  class Comment; end

  PostDB = Struct.new(:id, :best_comment_id, keyword_init: true)

  CommentDB = Struct.new(:id, :post_id, keyword_init: true)

  before(:all) do
    # define_table('comments', {post_id: :integer}, false)
    # CommentDB = defineAr('comments')

    # define_table('posts', {best_comment_id: :integer}, false)
    # PostDB = defineAr('posts')
  end

  # it 'loads an object once even when referred to by different associations of different types2' do
  #   post_config = Vorpal.build_class_config(Post) do
  #     attributes :name
  #     belongs_to :best_comment, child_class: Comment
  #     has_many :comments
  #   end
  #
  #   comment_config = Vorpal.build_class_config(Comment) do
  #     attributes :length
  #   end
  #
  #   main_config = Vorpal::MainConfig.new([post_config, comment_config])
  #
  #   driver = Vorpal::Postgresql.new
  #
  #   best_comment_db = CommentDB.create!
  #   post_db = PostDB.create!(best_comment_id: best_comment_db.id)
  #   best_comment_db.update_attributes!(post_id: post_db.id)
  #
  #   loader = Vorpal::DbLoader.new(false, driver)
  #   loaded_objects = loader.load_from_db([post_db.id], main_config.config_for(Post))
  #   p loaded_objects.all_objects
  #   # expect(loaded_objects.all_objects.size).to eq(2)
  #
  #   repo = Vorpal::AggregateMapper.new(driver, main_config)
  #   post = repo.load(post_db.id, Post)
  #   p post
  #   expect(post.comments.size).to eq(1)
  # end

  it 'loads an object once even when referred to by different associations of different types with stubs' do
    engine = Vorpal.define do
      map(Post, to: PostDB) do
        attributes :name
        belongs_to :best_comment, child_class: Comment
        has_many :comments
      end

      map(Comment, to: CommentDB) do
        attributes :length
      end
    end

    best_comment_db = CommentDB.new
    best_comment_db.id = 99
    post_db = PostDB.new(best_comment_id: best_comment_db.id)
    post_db.id = 100
    best_comment_db.post_id = post_db.id

    driver = instance_double("Vorpal::Driver::Postgresql")
    expect(driver).to receive(:load_by_id).with(PostDB, [post_db.id]).and_return([post_db])
    expect(driver).to receive(:load_by_id).with(CommentDB, [best_comment_db.id]).and_return([best_comment_db])
    expect(driver).to receive(:load_by_foreign_key).and_return([best_comment_db])

    loader = Vorpal::DbLoader.new(false, driver)
    loaded_objects = loader.load_from_db([post_db.id], engine.class_config(Post))

    expect(loaded_objects.all_objects).to contain_exactly(post_db, best_comment_db)
  end
end
