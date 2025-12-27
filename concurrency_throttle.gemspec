# frozen_string_literal: true

require_relative "lib/concurrency_throttle/version"

Gem::Specification.new do |spec|
  spec.name = "concurrency_throttle"
  spec.version = ConcurrencyThrottle::VERSION
  spec.authors = ["Josh Pencheon"]

  spec.summary = "Cooperative rate limiting with MySQL advisory locks"
  spec.description = "An implementation of cooperative rate-limited processing using MySQL advisory locks to coordinate concurrency limits across multiple processes."
  spec.homepage = "https://github.com/joshpencheon/limit_locks"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir[
    "lib/**/*.rb",
    "LICENSE.txt",
    "README.md"
  ]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "activerecord", ">= 7.0"

  # Development dependencies
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "mysql2", "~> 0.5"
  spec.add_development_dependency "rake", "~> 13.0"
end
