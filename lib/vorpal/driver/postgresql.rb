require 'vorpal/util/string_utils.rb'

module Vorpal
  module Driver
    # Interface between the database and Vorpal for PostgreSQL using ActiveRecord.
    class Postgresql
      def initialize
        @sequence_names = {}
      end

      def insert(db_class, db_objects)
        if ActiveRecord::VERSION::MAJOR >= 6
          return if db_objects.empty?

          update_timestamps_on_create(db_class, db_objects)
          db_class.insert_all!(db_objects.map(&:attributes))
        elsif defined? ActiveRecord::Import
          db_class.import(db_objects, validate: false)
        else
          db_objects.each do |db_object|
            db_object.save!(validate: false)
          end
        end
      end

      def update(db_class, db_objects)
        if ActiveRecord::VERSION::MAJOR >= 6
          return if db_objects.empty?

          update_timestamps_on_update(db_class, db_objects)
          db_class.upsert_all(db_objects.map(&:attributes))
        else
          db_objects.each do |db_object|
            db_object.save!(validate: false)
          end
        end
      end

      def destroy(db_class, ids)
        db_class.where(id: ids).delete_all
      end

      # Loads instances of the given class by a unique key.
      #
      # @param db_class [Class] A subclass of ActiveRecord::Base
      # @return [[Object]] An array of entities.
      def load_by_unique_key(db_class, ids, column_name)
        db_class.where(column_name => ids).to_a
      end

      # Loads instances of the given class whose foreign key has the given value.
      #
      # @param db_class [Class] A subclass of ActiveRecord::Base
      # @param id [Integer] The value of the foreign key to find by. (Can also be an array of ids.)
      # @param foreign_key_info [ForeignKeyInfo] Meta data for the foreign key.
      # @return [[Object]] An array of entities.
      def load_by_foreign_key(db_class, id, foreign_key_info)
        arel = db_class.where(foreign_key_info.fk_column => id)
        arel = arel.where(foreign_key_info.fk_type_column => foreign_key_info.fk_type) if foreign_key_info.polymorphic?
        arel.to_a
      end

      # Fetches primary key values to be used for new entities.
      #
      # @param db_class [Class] A subclass of ActiveRecord::Base
      # @return [[Integer]] An array of unused primary keys.
      def get_primary_keys(db_class, count)
        result = execute("select nextval($1) from generate_series(1,$2);", [
          ActiveRecord::Relation::QueryAttribute.new("sequence_name", sequence_name(db_class), ActiveRecord::Type::String.new),
          ActiveRecord::Relation::QueryAttribute.new("count", count, ActiveRecord::Type::Integer.new)
        ])
        result.rows.map(&:first).map(&:to_i)
      end

      # Builds an ORM Class for accessing data in the given DB table.
      #
      # @param model_class [Class] The PORO class that we are creating a DB interface class for.
      # @param table_name [String] Name of the DB table the DB class should interface with.
      # @return [Class] ActiveRecord::Base Class
      def build_db_class(model_class, table_name)
        db_class = Class.new(ActiveRecord::Base) do
          class << self
            # This is overridden for two reasons:
            # 1) For anonymous classes, #name normally returns nil. Class names in Ruby come from the
            #   name of the constant they are assigned to.
            # 2) Because the default implementation for Class#name for anonymous classes is very, very
            #   slow. https://bugs.ruby-lang.org/issues/11119
            # Remove this override once #2 has been fixed!
            def name
              @name ||= "Vorpal_generated_ActiveRecord__Base_class_for_#{vorpal_model_class_name}"
            end

            # Overridden because, like #name, the default implementation for anonymous classes is very,
            # very slow.
            def to_s
              name
            end

            attr_accessor :vorpal_model_class_name
          end
        end

        db_class.vorpal_model_class_name = Util::StringUtils.escape_class_name(model_class.name)
        db_class.table_name = table_name
        db_class.primary_key = 'id'
        db_class
      end

      # Builds a composable query object (e.g. ActiveRecord::Relation) with Vorpal methods mixed in
      # for querying for instances of the given AR::Base class.
      #
      # @param db_class [Class] A subclass of ActiveRecord::Base
      def query(db_class, aggregate_mapper)
        db_class.unscoped.extending(ArelQueryMethods.new(aggregate_mapper))
      end

      private

      # Adapted from https://github.com/rails/rails/blob/614580270d7789e5275defc3da020ce27b3b2302/activerecord/lib/active_record/timestamp.rb#L99
      def update_timestamps_on_create(db_class, db_objects)
        return unless db_class.record_timestamps

        current_time = db_class.current_time_from_proper_timezone
        db_objects.each do |db_object|
          db_class.all_timestamp_attributes_in_model.each do |column|
            db_object.write_attribute(column, current_time) unless db_object.read_attribute(column)
          end
        end
      end

      #Adapted from https://github.com/rails/rails/blob/614580270d7789e5275defc3da020ce27b3b2302/activerecord/lib/active_record/timestamp.rb#L111
      def update_timestamps_on_update(db_class, db_objects)
        return unless db_class.record_timestamps

        current_time = db_class.current_time_from_proper_timezone
        db_objects.each do |db_object|
          db_class.timestamp_attributes_for_update_in_model.each do |column|
            db_object.write_attribute(column, current_time)
          end
        end
      end

      def sequence_name(db_class)
        @sequence_names[db_class] ||= execute(
          "SELECT substring(column_default from '''(.*)''') FROM INFORMATION_SCHEMA.COLUMNS WHERE table_name = $1 AND column_name = 'id' LIMIT 1",
          [ActiveRecord::Relation::QueryAttribute.new("table_name", db_class.table_name, ActiveRecord::Type::String.new)]
        ).rows.first.first
      end

      def execute(sql, binds)
        ActiveRecord::Base.connection.exec_query(sql, 'SQL', binds)
      end
    end

    class ArelQueryMethods < Module
      def initialize(mapper)
        @mapper = mapper
      end

      def extended(descendant)
        super
        descendant.extend(Methods)
        descendant.vorpal_aggregate_mapper = @mapper
      end

      # Methods in this module will appear on any composable
      module Methods
        attr_writer :vorpal_aggregate_mapper

        # See {AggregateMapper#load_many}.
        def load_many
          db_roots = self.to_a
          @vorpal_aggregate_mapper.load_many(db_roots)
        end

        # See {AggregateMapper#load_one}.
        def load_one
          db_root = self.first
          @vorpal_aggregate_mapper.load_one(db_root)
        end
      end
    end
  end
end
