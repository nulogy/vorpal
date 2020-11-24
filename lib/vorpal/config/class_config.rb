require 'equalizer'

module Vorpal
  module Config
    # @private
    class ClassConfig
      include Equalizer.new(:domain_class, :db_class)
      attr_reader :serializer, :deserializer, :domain_class, :db_class, :primary_key_type, :local_association_configs
      attr_accessor :has_manys, :belongs_tos, :has_ones

      ALLOWED_PRIMARY_KEY_TYPE_OPTIONS = [:serial, :uuid]

      def initialize(attrs)
        @has_manys = []
        @belongs_tos = []
        @has_ones = []
        @local_association_configs = []

        @serializer = attrs[:serializer]
        @deserializer = attrs[:deserializer]
        @domain_class = attrs[:domain_class]
        @db_class = attrs[:db_class]
        @primary_key_type = attrs[:primary_key_type]
        raise "Invalid primary_key_type: '#{@primary_key_type}'" unless ALLOWED_PRIMARY_KEY_TYPE_OPTIONS.include?(@primary_key_type)
      end

      def build_db_object(attributes)
        db_class.new(attributes)
      end

      def set_db_object_attributes(db_object, attributes)
        db_object.attributes = attributes
      end

      def get_db_object_attributes(db_object)
        symbolize_keys(db_object.attributes)
      end

      def serialization_required?
        domain_class.superclass.name != 'ActiveRecord::Base'
      end

      def serialize(object)
        serializer.serialize(object)
      end

      def deserialize(db_object)
        attributes = get_db_object_attributes(db_object)
        serialization_required? ? deserializer.deserialize(domain_class.new, attributes) : db_object
      end

      def set_attribute(db_object, attribute, value)
        db_object.send("#{attribute}=", value)
      end

      def get_attribute(db_object, attribute)
        db_object.send(attribute)
      end

      private

      def symbolize_keys(hash)
        result = {}
        hash.each_key do |key|
          result[key.to_sym] = hash[key]
        end
        result
      end
    end
  end
end
