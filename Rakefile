#!/usr/bin/env rake
begin
  require "bundler/gem_tasks"
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks associated with creating new versions of the gem.'
end

begin
  require 'rspec/core/rake_task'

  namespace :spec do
    RSpec::Core::RakeTask.new(:acceptance) do |t|
      t.pattern = "spec/vorpal/acceptance/**/*_spec.rb"
    end

    RSpec::Core::RakeTask.new(:integration) do |t|
      t.pattern = "spec/vorpal/integration/**/*_spec.rb"
    end

    RSpec::Core::RakeTask.new(:performance) do |t|
      t.pattern = "spec/vorpal/performance/**/*_spec.rb"
    end

    RSpec::Core::RakeTask.new(:unit) do |t|
      t.pattern = "spec/vorpal/unit/**/*_spec.rb"
    end

    desc "Run all non-performance related specs"
    task non_perf: [:unit, :integration, :acceptance]

    desc "Run all specs"
    task all: [:acceptance, :integration, :unit, :performance]
  end

  task default: :'spec:all'
rescue LoadError
  # Allow the Rakefile to be used in environments where the RSpec gem is unavailable
  # (e.g. Production)
end
