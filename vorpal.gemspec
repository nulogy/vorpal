# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vorpal/version'

Gem::Specification.new do |spec|
  spec.name          = "vorpal"
  spec.version       = Vorpal::VERSION
  spec.authors       = ["Sean Kirby"]
  spec.email         = ["seank@nulogy.com"]
  spec.summary       = %q{Separate your domain model from your persistence mechanism.}
  spec.description   = %q{An ORM framelet that fits on top of ActiveRecord to give you 'Data Mapper' semantics.}
  spec.homepage      = "https://github.com/nulogy/vorpal"
  spec.license       = "MIT"

  spec.files         = Dir["CHANGELOG.md", "LICENSE.txt", "README.md", "vorpal.gemspec", "lib/**/*"]
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "simple_serializer", "~> 1.0"
  spec.add_runtime_dependency "equalizer"
  spec.add_runtime_dependency "activesupport"

  spec.add_development_dependency "rake", "~> 13"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "appraisal", "~> 2.2"

  spec.required_ruby_version = ">= 2.5.7"
  spec.add_development_dependency "activerecord"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "activerecord-import"
  spec.add_development_dependency "codecov"
end
