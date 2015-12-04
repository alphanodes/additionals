#!/bin/bash

function build_redmine()
{
  BRANCH="$1"
  REDMINE_DIR="redmine-${BRANCH}"
  git clone https://github.com/redmine/redmine -b $BRANCH $REDMINE_DIR
  cat << HERE >> ${REDMINE_DIR}/config/database.yml
  test:
    adapter: sqlite3
    database: db/test.sqlite3
HERE

  mv $PLUGIN_NAME ${REDMINE_DIR}/plugins
  cd ${REDMINE_DIR} || exit 1
  gem update bundler
  cat << FILE >> Gemfile.local
  gem 'brakeman'
  gem 'flog'
  gem 'rubocop'
  gem "ci_reporter_minitest"
  gem 'rubocop-checkstyle_formatter', require: false
FILE

  bundle install --path vendor/bundle --without mysql postgreql rmagick --with test
  bundle exec rake db:migrate RAILS_ENV=test
  bundle exec rake db:migrate_plugins RAILS_ENV=test
  bundle exec rake redmine:plugins:test RAILS_ENV=test

  bundle exec rake redmine:plugins:migrate NAME=${PLUGIN_NAME} VERSION=0 RAILS_ENV=test

  cd plugins/$PLUGIN_NAME || exit 2
  pwd
}

cd ..
rm -fr redmine-*

BUILD_RUNS=${#REDMINE_BRANCHES}
for ((i=0;i<$BUILD_RUNS;i++)); do
    TARGET=${REDMINE_BRANCHES[${i}]}
    build_redmine $TARGET
    cd ..
done
