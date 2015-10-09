namespace :jenkins_ci do
  require 'ci/reporter/rake/minitest'
  task test: ['ci:setup:minitest', 'redmine:plugins:test']
end
