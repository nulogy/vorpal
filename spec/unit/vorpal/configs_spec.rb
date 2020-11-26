require 'unit_spec_helper'
require 'vorpal/configs'
require 'vorpal/config/main_config'
require 'vorpal/config/class_config'

describe Vorpal::Config::MainConfig do
  class Post
    attr_accessor :comments
    attr_accessor :best_comment
  end

  class Comment
    attr_accessor :post
  end

  let(:post_config) { Vorpal::Config::ClassConfig.new(domain_class: Post, primary_key_type: :serial) }
  let(:comment_config) { Vorpal::Config::ClassConfig.new(domain_class: Comment, primary_key_type: :serial) }
  let(:post_has_many_comments_config) { Vorpal::HasManyConfig.new(name: 'comments', fk: 'post_id', child_class: Comment) }
  let(:post_has_one_comment_config) { Vorpal::HasOneConfig.new(name: 'best_comment', fk: 'post_id', child_class: Comment) }
  let(:comment_belongs_to_post_config) { Vorpal::BelongsToConfig.new(name: 'post', fk: 'post_id', child_classes: [Post]) }

  describe 'local_association_configs' do
    it 'builds an association_config for a belongs_to' do
      comment_config.belongs_tos << comment_belongs_to_post_config

      initialize_association_configs([post_config, comment_config])

      expect(comment_config.local_association_configs.size).to eq(1)
      expect(post_config.local_association_configs.size).to eq(0)
    end

    it 'sets the association end configs' do
      comment_config.belongs_tos << comment_belongs_to_post_config
      post_config.has_manys << post_has_many_comments_config

      initialize_association_configs([post_config, comment_config])

      association_config = comment_config.local_association_configs.first

      expect(association_config.remote_end_config).to eq(post_has_many_comments_config)
      expect(association_config.local_end_config).to eq(comment_belongs_to_post_config)
    end

    it 'builds an association_config for a has_many' do
      post_config.has_manys << post_has_many_comments_config

      initialize_association_configs([post_config, comment_config])

      expect(comment_config.local_association_configs.size).to eq(1)
      expect(post_config.local_association_configs.size).to eq(0)
    end
  end

  def initialize_association_configs(configs)
    main_config = Vorpal::Config::MainConfig.new
    configs.each do |config|
      main_config.add_class_config(config)
    end
    main_config.initialize_association_configs
  end

  describe 'nice user feedback' do
    it 'lets the user know what the problem is when a configuration is missing' do
      main_config = Vorpal::Config::MainConfig.new

      expect {
        main_config.config_for(String)
      }.to raise_error(Vorpal::ConfigurationNotFound, "No configuration found for String")
    end
  end

  describe Vorpal::AssociationConfig do
    describe 'associate' do
      let(:post) { Post.new }
      let(:comment) { Comment.new }

      it 'sets both ends of a one-to-one association' do
        config = Vorpal::AssociationConfig.new(comment_config, 'post_id', nil)
        config.add_remote_class_config(post_config)

        config.local_end_config = comment_belongs_to_post_config
        config.remote_end_config = post_has_one_comment_config

        config.associate(comment, post)

        expect(comment.post).to eq(post)
        expect(post.best_comment).to eq(comment)
      end

      it 'sets both ends of a one-to-many association' do
        config = Vorpal::AssociationConfig.new(comment_config, 'post_id', nil)
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
        config = Vorpal::AssociationConfig.new(comment_config, 'post_id', nil)
        config.add_remote_class_config(post_config)

        post = Post.new
        class_config = config.remote_class_config(post)

        expect(class_config).to eq(post_config)
      end

      it 'works with polymorphic associations' do
        config = Vorpal::AssociationConfig.new(comment_config, 'commented_upon_id', 'commented_upon_type')
        config.add_remote_class_config(post_config)
        config.add_remote_class_config(comment_config)

        comment = double('comment', commented_upon_type: 'Comment')
        class_config = config.remote_class_config(comment)

        expect(class_config).to eq(comment_config)
      end
    end
  end
end
