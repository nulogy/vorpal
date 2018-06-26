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

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.1.6"

  spec.add_runtime_dependency "simple_serializer", "~> 1.0"
  spec.add_runtime_dependency "equalizer"
  spec.add_runtime_dependency "activesupport"

  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "activerecord", "~> 4.0"
  spec.add_development_dependency "pg", "~> 0.17.0"
  spec.add_development_dependency "virtus", "~> 1.0"
  spec.add_development_dependency "activerecord-import", "~> 0.10.0"
end
