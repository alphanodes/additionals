#!/bin/bash

set -e

if [[ ! "$TESTSPACE" = /* ]] ||
   [[ ! "$PATH_TO_REDMINE" = /* ]] ||
   [[ ! "$REDMINE_VER" = * ]] ||
   [[ ! "$NAME_OF_PLUGIN" = * ]] ||
   [[ ! "$PATH_TO_PLUGIN" = /* ]];
then
  echo "You should set"\
       " TESTSPACE, PATH_TO_REDMINE, REDMINE_VER"\
       " NAME_OF_PLUGIN, PATH_TO_PLUGIN"\
       " environment variables"
  echo "You set:"\
       "$TESTSPACE"\
       "$PATH_TO_REDMINE"\
       "$REDMINE_VER"\
       "$NAME_OF_PLUGIN"\
       "$PATH_TO_PLUGIN"
  exit 1;
fi

export RAILS_ENV=test

export REDMINE_GIT_REPO=git://github.com/redmine/redmine.git
export REDMINE_GIT_TAG=$REDMINE_VER
export BUNDLE_GEMFILE=$PATH_TO_REDMINE/Gemfile

# checkout redmine
git clone $REDMINE_GIT_REPO $PATH_TO_REDMINE
cd $PATH_TO_REDMINE
if [ ! "$REDMINE_GIT_TAG" = "master" ];
then
  git checkout -b $REDMINE_GIT_TAG origin/$REDMINE_GIT_TAG
fi

# create a link to the backlogs plugin
ln -sf $PATH_TO_PLUGIN plugins/$NAME_OF_PLUGIN

mv $TESTSPACE/database.yml.travis config/database.yml
mv $TESTSPACE/additional_environment.rb config/

# install gems
bundle install

# run redmine database migrations
bundle exec rake db:migrate

# run plugin database migrations
bundle exec rake redmine:plugins:migrate

# install redmine database
#bundle exec rake redmine:load_default_data REDMINE_LANG=en

bundle exec rake db:structure:dump

# run tests
# bundle exec rake TEST=test/unit/role_test.rb
bundle exec rake redmine:plugins:test NAME=$NAME_OF_PLUGIN
