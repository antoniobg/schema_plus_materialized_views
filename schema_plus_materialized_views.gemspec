# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'schema_plus/materialized_views/version'

Gem::Specification.new do |gem|
  gem.name          = "schema_plus_materialized_views"
  gem.version       = SchemaPlus::MaterializedViews::VERSION
  gem.authors       = ["Antonio Borrero Granell"]
  gem.email         = ["me@antoniobg.com"]
  gem.summary       = %q{Adds support for materialized views to ActiveRecord}
  gem.homepage      = "https://github.com/antoniobg/schema_plus_materialized_views"
  gem.license       = "MIT"

  gem.files         = `git ls-files -z`.split("\x0")
  gem.executables   = gem.files.grep(%r{^bin/}) { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency "activerecord", "~> 4.2"
  gem.add_dependency "schema_plus_core", "~> 0.1"

  gem.add_development_dependency "bundler", "~> 1.7"
  gem.add_development_dependency "rake", "~> 10.0"
  gem.add_development_dependency "rspec", "~> 3.0"
  gem.add_development_dependency "schema_dev", "~> 3.3"
  gem.add_development_dependency "simplecov"
  gem.add_development_dependency "simplecov-gem-profile"
end
