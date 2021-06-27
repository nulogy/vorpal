require 'unit_spec_helper'
require 'vorpal/config/main_config'
require 'vorpal/config/class_config'

module MainConfigSpec
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
    let(:post_has_many_comments_config) { Vorpal::Config::HasManyConfig.new(name: 'comments', fk: 'post_id', child_class: Comment) }
    let(:post_has_one_comment_config) { Vorpal::Config::HasOneConfig.new(name: 'best_comment', fk: 'post_id', child_class: Comment) }
    let(:comment_belongs_to_post_config) { Vorpal::Config::BelongsToConfig.new(name: 'post', fk: 'post_id', associated_classes: [Post]) }

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
  end
end
