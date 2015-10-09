namespace :redmine_tweaks do

  namespace :ci do
    begin
      require 'ci/reporter/rake/minitest'
    rescue Exception => e
    else
#      ENV['CI_REPORTS'] = Rails.root.join('log/reports').to_s
      ENV['NAME'] = 'redmine_tweaks'
    end

    task all: ['ci:setup:minitest', 'redmine:plugins:test']
  end

  task default: 'redmine_tweaks:ci:all'
end
