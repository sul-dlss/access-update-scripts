#!/bin/bash

SCRIPT_PATH=$(cd "$(dirname "$0")" ; pwd -P)
RUBY_REPOS_FILE="${REPOS_PATH:-$SCRIPT_PATH}/ruby"
JS_REPOS_FILE="${REPOS_PATH:-$SCRIPT_PATH}/javascript"

CLONE_LOCATION=${WORKSPACE:-$TMPDIR}

cd $CLONE_LOCATION
mkdir -p $CLONE_LOCATION/.autoupdate
cd $CLONE_LOCATION/.autoupdate

mkdir gem_report
mkdir npm_report

GEM_SUCCESS_REPORTS_ARRAY=("/dev/null")
NPM_SUCCESS_REPORTS_ARRAY=("/dev/null")

# Ruby / Rails applications
while IFS='' read -r repo || [[ -n "$repo" ]]; do
  echo $repo
  cd $CLONE_LOCATION/.autoupdate
  git clone git@github.com:sul-dlss/$repo
  cd $repo
  git fetch origin
  git checkout -B update-dependencies
  git reset --hard  origin/master
  bundle update > $CLONE_LOCATION/.autoupdate/gem_report/$repo.txt &&
    git add Gemfile.lock &&
    git commit -m "Update dependencies" &&
    git push origin update-dependencies &&
    hub pull-request -f -m "Update dependencies"

  retVal=$?

  if [ $retVal -ne 0 ]; then
    echo "ERROR UPDATING ${repo}"
    cat $CLONE_LOCATION/.autoupdate/gem_report/$repo.txt
  else
    GEM_SUCCESS_REPORTS_ARRAY+=("$CLONE_LOCATION/.autoupdate/gem_report/$repo.txt")
  fi

  echo " ===== "
done < $RUBY_REPOS_FILE

# JavaScript applications
while IFS='' read -r repo || [[ -n "$repo" ]]; do
  echo $repo
  cd $CLONE_LOCATION/.autoupdate
  git clone git@github.com:sul-dlss/$repo
  cd $repo
  git fetch origin
  git checkout -B update-dependencies
  git reset --hard  origin/master

  npm audit fix > $CLONE_LOCATION/.autoupdate/npm_report/$repo.txt &&
  git add package-lock.json package.json &&
  git commit -m "Update dependencies" &&
  git push origin update-dependencies &&
  hub pull-request -f -m "Update dependencies"

  retVal=$?

  if [ $retVal -ne 0 ]; then
    echo "ERROR UPDATING ${repo}"
    cat $CLONE_LOCATION/.autoupdate/npm_report/$repo.txt
  else
    NPM_SUCCESS_REPORTS_ARRAY+=("$CLONE_LOCATION/.autoupdate/npm_report/$repo.txt")
  fi
done < $JS_REPOS_FILE

cd $SCRIPT_PATH
./slack_bot.rb "Dependency Updates Shipped!"
./slack_bot.rb "`cat ${GEM_SUCCESS_REPORTS_ARRAY[*]} | grep "(was " | cut -f 2-5 -d " " | sort | uniq`"
