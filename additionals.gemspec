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
  spec.required_ruby_version = '>= 3.1'

  spec.add_dependency 'redmine_plugin_kit'
  spec.add_dependency 'render_async'
  spec.add_dependency 'rss'
  spec.add_dependency 'slim-rails'
  # TODO: tanuki_emoji 0.11.0 is not compatible with Redmine 5.0
  # we should switch to latest version after dropping Redmine 5.0 support
  spec.add_dependency 'tanuki_emoji', '~> 0.10.0'
end
