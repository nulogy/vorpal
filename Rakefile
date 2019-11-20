#!/usr/bin/env rake
begin
  require "bundler/gem_tasks"
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks associated with creating new versions of the gem.'
end

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:acceptance_specs) do |t|
    t.pattern = "spec/vorpal/acceptance/**/*_spec.rb"
  end

  RSpec::Core::RakeTask.new(:integration_specs) do |t|
    t.pattern = "spec/vorpal/integration/**/*_spec.rb"
  end

  RSpec::Core::RakeTask.new(:performance_specs) do |t|
    t.pattern = "spec/vorpal/performance/**/*_spec.rb"
  end

  RSpec::Core::RakeTask.new(:unit_specs) do |t|
    t.pattern = "spec/vorpal/unit/**/*_spec.rb"
  end

  task :default => [:acceptance_specs, :integration_specs, :unit_specs, :performance_specs]
rescue LoadError
  # Allow the Rakefile to be used in environments where the RSpec gem is unavailable
  # (e.g. Production)
end
