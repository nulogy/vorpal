require 'unit_spec_helper'
require 'vorpal/config/main_config'
require 'vorpal/config/class_config'

module ConfigsSpec
  describe Vorpal::Config::AssociationConfig do
    class Post
      attr_accessor :comments
      attr_accessor :best_comment
    end

    class Comment
      attr_accessor :post
    end

    let(:post_config) { Vorpal::Config::ClassConfig.new(domain_class: Post, primary_key_type: :serial) }
    let(:comment_config) { Vorpal::Config::ClassConfig.new(domain_class: Comment, primary_key_type: :serial) }
    let(:post_has_many_comments_config) { Vorpal::Config::HasManyConfig.new(name: 'comments', fk: 'post_id', associated_class: Comment) }
    let(:post_has_one_comment_config) { Vorpal::Config::HasOneConfig.new(name: 'best_comment', fk: 'post_id', associated_class: Comment) }
    let(:comment_belongs_to_post_config) { Vorpal::Config::BelongsToConfig.new(name: 'post', fk: 'post_id', associated_classes: [Post]) }

    describe 'associate' do
      let(:post) { Post.new }
      let(:comment) { Comment.new }

      it 'sets both ends of a one-to-one association' do
        config = Vorpal::Config::AssociationConfig.new(comment_config, 'post_id', nil)
        config.add_remote_class_config(post_config)

        config.local_end_config = comment_belongs_to_post_config
        config.remote_end_config = post_has_one_comment_config

        config.associate(comment, post)

        expect(comment.post).to eq(post)
        expect(post.best_comment).to eq(comment)
      end

      it 'sets both ends of a one-to-many association' do
        config = Vorpal::Config::AssociationConfig.new(comment_config, 'post_id', nil)
        config.add_remote_class_config(post_config)

        config.local_end_config = comment_belongs_to_post_config
        config.remote_end_config = post_has_many_comments_config

        config.associate(comment, post)

        expect(comment.post).to eq(post)
        expect(post.comments).to eq([comment])
      end
    end

    describe 'remote_class_config' do
      it 'works with non-polymorphic associations' do
        config = Vorpal::Config::AssociationConfig.new(comment_config, 'post_id', nil)
        config.add_remote_class_config(post_config)

        post = Post.new
        class_config = config.remote_class_config(post)

        expect(class_config).to eq(post_config)
      end

      it 'works with polymorphic associations' do
        config = Vorpal::Config::AssociationConfig.new(comment_config, 'commented_upon_id', 'commented_upon_type')
        config.add_remote_class_config(post_config)
        config.add_remote_class_config(comment_config)

        comment = double('comment', commented_upon_type: 'ConfigsSpec::Comment')
        class_config = config.remote_class_config(comment)

        expect(class_config).to eq(comment_config)
      end
    end
  end
end
