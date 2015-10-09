namespace :jenkins_ci do
  if ENV['CI_REPORTS'].nil?
    abort "jenkins_ci requires CI_REPORTS."
  else
    require 'ci/reporter/rake/minitest'
  end
  task test: ['ci:setup:minitest', 'redmine:plugins:test']
end
