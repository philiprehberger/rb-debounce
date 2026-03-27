# frozen_string_literal: true

require_relative 'lib/philiprehberger/debounce/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-debounce'
  spec.version       = Philiprehberger::Debounce::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['me@philiprehberger.com']
  spec.summary       = 'Debounce and throttle decorators for Ruby method calls'
  spec.description   = 'Debounce delays execution until a quiet period elapses. Throttle limits execution ' \
                       'frequency. Both are thread-safe with leading/trailing edge options and cancel/flush control.'
  spec.homepage      = 'https://github.com/philiprehberger/rb-debounce'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'
  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri']       = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.files = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
