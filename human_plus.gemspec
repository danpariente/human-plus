# frozen_string_literal: true

require_relative "lib/human_plus/version"

Gem::Specification.new do |spec|
  spec.name = "human_plus"
  spec.version = HumanPlus::VERSION
  spec.authors = ["danpariente"]
  spec.email = ["dansification@gmail.com"]

  spec.summary = "The mind as a programmable system — Hawkins' Letting Go, rendered in Ruby."
  spec.description =
    "A didactic-art rendering of David R. Hawkins' \"Letting Go\" in which the book's " \
    "mechanics are the language's mechanics: feelings are installed as real methods, " \
    "surrender removes them, and FEELINGS = PROGRAMS = RESPONSES is a statement about " \
    "constants. Includes a generative-agents town after Park et al. (arXiv:2304.03442): " \
    "pressure contagion, conversations, a memory stream of grudges, charts, and a " \
    "first-person mode that asks you the question an NPC never gets."
  spec.homepage = "https://github.com/danpariente/human-plus"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "data/*.csv", "bin/human+", "README.md", "LICENSE", "Rakefile"]
  spec.bindir = "bin"
  spec.executables = ["human+"]
  spec.require_paths = ["lib"]

  # Everything below ships with Ruby as a bundled/default gem — declared
  # because Ruby 3.4+ no longer default-loads csv under bundler.
  spec.add_dependency "csv"
  spec.add_dependency "json"

  # The generative narrator borrows its Mind from the `anthropic` gem,
  # loaded only when one is constructed — deliberately NOT a dependency.
end
