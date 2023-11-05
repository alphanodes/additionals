# frozen_string_literal: true

lib = File.expand_path '../lib', __FILE__
$LOAD_PATH.unshift lib unless $LOAD_PATH.include? lib
require 'additionals/plugin_version'

Gem::Specification.new do |spec|
  spec.name          = 'additionals'
  spec.version       = Additionals::PluginVersion::VERSION
  spec.authors       = ['AlphaNodes']
  spec.email         = ['alex@alphanodes.com']
  spec.metadata      = { 'rubygems_mfa_required' => 'true' }

  spec.summary       = 'Redmine plugin for adding dashboard functionality, wiki macros and libraries for other Redmine plugins'
  spec.description   = 'Redmine plugin for adding dashboard functionality, wiki macros and libraries for other Redmine plugins'
  spec.homepage      = 'https://github.com/alphanodes/alphanodes'
  spec.license       = 'GPL-2.0'

  spec.files         = Dir['**/*'].reject do |f|
    f.match %r{^((contrib|test|node_modules)/|Gemfile|Gemfile\.lock|additionals\.gemspec|package\.json|yarn\.lock)}
  end
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.0'

  spec.add_runtime_dependency 'redmine_plugin_kit'
  spec.add_runtime_dependency 'render_async'
  spec.add_runtime_dependency 'rss'
  spec.add_runtime_dependency 'slim-rails'
  spec.add_runtime_dependency 'tanuki_emoji', '~> 0.6'
end
