#!/usr/bin/env rake
begin
  require "bundler/gem_tasks"
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks associated with creating new versions of the gem.'
end

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
task :default => :spec