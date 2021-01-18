lib = File.expand_path '../lib', __FILE__
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'additionals/version'

Gem::Specification.new do |spec|
  spec.name          = 'additionals'
  spec.version       = Additionals::VERSION
  spec.authors       = ['AlphaNodes']
  spec.email         = ['alex@alphanodes.com']

  spec.summary       = 'Redmine plugin for adding dashboard functionality, wiki macros and libraries for other Redmine plugins'
  spec.description   = 'Redmine plugin for adding dashboard functionality, wiki macros and libraries for other Redmine plugins'
  spec.homepage      = 'https://github.com/alphanodes/alphanodes'
  spec.license       = 'GPL-2.0'

  spec.files         = Dir['**/*'] - Dir['test/**/*'] - Dir['Gemfile', 'Gemfile.lock']
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.4'

  spec.add_runtime_dependency 'deface', '1.5.3'
  spec.add_runtime_dependency 'gemoji', '~> 3.0.0'
  spec.add_runtime_dependency 'render_async'
  spec.add_runtime_dependency 'rss'
  spec.add_runtime_dependency 'slim-rails'

  spec.add_development_dependency 'brakeman'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'slim_lint'
end
