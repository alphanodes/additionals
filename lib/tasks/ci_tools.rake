namespace :redmine_tweaks do

  namespace :ci do
    begin
      require 'ci/reporter/rake/minitest'
    rescue Exception => e
    else
      puts 'Prepare jenkins jobs...'
#      ENV['CI_REPORTS'] = Rails.root.join('log/reports').to_s
    end

    task all: ['ci:setup:minitest', 'redmine:plugins:test']
  end

  task default: 'redmine_tweaks:ci:all'
end
