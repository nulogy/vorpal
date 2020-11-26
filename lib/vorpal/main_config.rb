module Vorpal
  # @private
  class MainConfig
    def initialize
      @class_configs = []
    end

    def config_for(clazz)
      config = @class_configs.detect { |conf| conf.domain_class == clazz }
      raise Vorpal::ConfigurationNotFound.new("No configuration found for #{clazz}") unless config
      config
    end

    def config_for_db_object(db_object)
      @class_configs.detect { |conf| conf.db_class == db_object.class }
    end

    def add_class_config(class_config)
      @class_configs << class_config
    end

    def initialize_association_configs
      association_configs = {}
      @class_configs.each do |config|
        (config.has_ones + config.has_manys).each do |association_end_config|
          child_config = config_for(association_end_config.child_class)
          association_end_config.set_parent_class_config(config)

          association_config = build_association_config(association_configs, child_config, association_end_config.fk, association_end_config.fk_type)
          association_config.remote_end_config = association_end_config
          association_config.add_remote_class_config(config)
          association_end_config.association_config = association_config
        end

        config.belongs_tos.each do |association_end_config|
          child_configs = association_end_config.child_classes.map(&method(:config_for))

          association_config = build_association_config(association_configs, config, association_end_config.fk, association_end_config.fk_type)
          association_config.local_end_config = association_end_config
          association_config.add_remote_class_config(child_configs)
          association_end_config.association_config = association_config
        end
      end

      association_configs.values.each do |association_config|
        association_config.local_class_config.local_association_configs << association_config
      end
    end

    private

    def build_association_config(association_configs, local_config, fk, fk_type)
      association_config = AssociationConfig.new(local_config, fk, fk_type)
      if association_configs[association_config]
        association_config = association_configs[association_config]
      else
        association_configs[association_config] = association_config
      end
      association_config
    end
  end
end
