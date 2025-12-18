# frozen_string_literal: true

gem 'redmine_plugin_kit'
gem 'render_async'
gem 'rss'
gem 'slim-rails'
gem 'tanuki_emoji', '~> 0.13.0'

# this is only used for local development.
# if you want to use it, do:
# - create .enable_dev file in additionals directory
#   (do not use for production!)
#   (this is used to not create conflicts with other plugins)
if File.file? File.expand_path './.enable_dev', __dir__
  group :development, :test do
    # gem 'awesome_print', require: 'ap'
    # gem 'better_errors'
    # gem 'binding_of_caller'
    gem 'debug'
    gem 'marginalia'
    gem 'memory_profiler'
    gem 'ruby-lsp'
  end
end

# if you want to use it for linters, do:
# - create .enable_test file in additionals directory
# - remove rubocop entries from REDMINE/Gemfile
# - remove REDMINE/.rubocop* files
# - create .enable_linters file in additionals directory
#   (do not use for production!)
#   (this is used to not create conflicts with other plugins)
if File.file? File.expand_path './.enable_linters', __dir__
  group :development, :test do
    gem 'brakeman', require: false
    gem 'rubocop', require: false
    gem 'rubocop-minitest', require: false
    gem 'rubocop-performance', require: false
    gem 'rubocop-rails', require: false
    gem 'slim_lint', require: false
  end
end

# if you want to use it for tests, do:
# - create .enable_test file in additionals directory
#   (this is used to not create conflicts with other plugins)
if File.file? File.expand_path './.enable_test', __dir__
  group :development, :test do
    # gem 'active_record_doctor'
    gem 'bullet'
    gem 'rails_best_practices', require: false
  end
  group :test do
    # Lock minitest to 5.x until a Rails release includes support for minitest 6.0
    # See: https://www.redmine.org/issues/43609
    # Can be removed once Redmine 6.x includes the fix (already in Redmine master)
    gem 'minitest', '~> 5.27'
    gem 'minitest-reporters'
    gem 'simplecov-cobertura' if ENV['COVERAGE_COBERTURA']
    gem 'timecop'
  end
end
