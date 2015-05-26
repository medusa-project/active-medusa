# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_medusa/version'

Gem::Specification.new do |spec|
  spec.authors       = ['Alex Dolski']
  spec.email         = ['alexd@illinois.edu']
  spec.name          = 'active-medusa'
  spec.version       = ActiveMedusa::VERSION
  spec.homepage      = 'http://github.com/medusa-project/active-medusa'
  spec.date          = '2015-05-08'
  spec.summary       = 'ActiveMedusa'
  spec.summary       = %q{Object-repositorial mapper for Fedora 4.1.}
  #spec.files         = Dir['lib/*.rb'] + Dir['test/**/*']
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ['lib']
  spec.license       = 'NCSA'
  spec.platform      = Gem::Platform::RUBY
  spec.required_ruby_version = '>= 2.0.0'
  spec.extra_rdoc_files = ['LICENSE', 'README.md']

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.add_runtime_dependency 'activemodel'
  spec.add_runtime_dependency 'activesupport'
  spec.add_runtime_dependency 'globalid'
  spec.add_runtime_dependency 'rdf'
  spec.add_runtime_dependency 'rdf-turtle'
  spec.add_runtime_dependency 'rsolr'
  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency 'rdoc'
  spec.add_development_dependency 'yard'
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'minitest-reporters'
end
