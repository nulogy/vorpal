require 'integration_spec_helper'
require 'vorpal'

module NonPersistedColumnsSpec
  describe 'Non Persisted Columns' do
    class Post
      attr_accessor :id
      attr_accessor :author
      attr_accessor :old_author

      def initialize(id: nil, author: nil, old_author: nil)
        @id, @author, @old_author = id, author, old_author
      end
    end

    before(:all) do
      define_table('post', {author: :string, old_author: :string}, false)
    end

    it 'does not include non-persisted columns in inserts' do
      test_mapper = configure

      db_class = db_class_for(Post, test_mapper)
      expect(db_class.ignored_columns).to eq([:old_author])
    end

    it 'does not include non-persisted columns in updates'
    it 'automatically determines non-persisted columns'

    private

    def db_class_for(clazz, mapper)
      mapper.engine.mapper_for(clazz).db_class
    end

    def configure(options={})
      engine = Vorpal.define(options) do
        map Post do
          attributes :author
          ignore_columns :old_author
        end
      end
      engine.mapper_for(Post)
    end
  end
end
