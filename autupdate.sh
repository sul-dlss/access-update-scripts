#!/bin/bash

# Usage:
#   GITHUB_TOKEN=my-private-token REPOS_PATH=/home/access-update-scripts/infrastructure WORKSPACE=/workspace ./autupdate.sh

SCRIPT_PATH=$(cd "$(dirname "$0")" ; pwd -P)
REPOS_FILE="${REPOS_PATH:-$SCRIPT_PATH}/projects.yml"
REPOS=$(./repos_wanting_update.rb $REPOS_FILE)
CLONE_LOCATION=${WORKSPACE:-$TMPDIR}

cd $CLONE_LOCATION
mkdir -p $CLONE_LOCATION/.autoupdate
cd $CLONE_LOCATION/.autoupdate

mkdir gem_report
mkdir npm_report
mkdir yarn_report

GEM_SUCCESS_REPORTS_ARRAY=("/dev/null")
NPM_SUCCESS_REPORTS_ARRAY=("/dev/null")
YARN_SUCCESS_REPORTS_ARRAY=("/dev/null")

# Ruby / Rails applications
for item in $REPOS; do
  IFS='/' read org repo <<< "$item"
  retVal=-1

  echo "$org/$repo"
  cd $CLONE_LOCATION/.autoupdate
  git clone git@github.com:$org/$repo
  cd $repo
  git fetch origin
  git checkout -B update-dependencies
  # This allows our default branches to vary across projects
  git reset --hard $(git symbolic-ref refs/remotes/origin/HEAD)

  if [[ -f '.autoupdate/preupdate' ]]; then
    .autoupdate/preupdate
    if [ $? -ne 0 ]; then
      continue
    fi
  fi

  if [[ -f '.autoupdate/update' ]]; then
    .autoupdate/update
  else
    if test -f '.circleci/config.yml' && grep -q ruby-rails .circleci/config.yml; then
      latest=$(circleci orb info sul-dlss/ruby-rails --skip-update-check | grep 'Latest:' | cut -d@ -f2)

      sed -i -e "s/sul-dlss\/ruby-rails@.*/sul-dlss\/ruby-rails@$latest/" .circleci/config.yml &&
        git add .circleci/config.yml &&
        git commit -m "Update CircleCI orb"
    fi

    if [[ -f 'Gemfile.lock' ]]; then
      bundle update --bundler > $CLONE_LOCATION/.autoupdate/gem_report/$repo.txt
      bundle update >> $CLONE_LOCATION/.autoupdate/gem_report/$repo.txt

      retVal=$?

      git add Gemfile.lock >> $CLONE_LOCATION/.autoupdate/gem_report/$repo.txt &&
        git commit -m "Update Ruby dependencies" >> $CLONE_LOCATION/.autoupdate/gem_report/$repo.txt

      if [ $retVal -ne 0 ]; then
        echo "ERROR UPDATING RUBY ${repo}"
        cat $CLONE_LOCATION/.autoupdate/gem_report/$repo.txt
      fi
    fi

    if [[ -f 'yarn.lock' ]]; then
      yarn upgrade > $CLONE_LOCATION/.autoupdate/yarn_report/$repo.txt

      retVal=$?

      git add yarn.lock &&
        git commit -m "Update Yarn dependencies"

      if [ $retVal -ne 0 ]; then
        echo "ERROR UPDATING YARN ${repo}"
        cat $CLONE_LOCATION/.autoupdate/yarn_report/$repo.txt
      fi
    fi

    if [[ -f 'package-lock.json' ]]; then
      npm update > $CLONE_LOCATION/.autoupdate/npm_report/$repo.txt &&
        npm audit fix > $CLONE_LOCATION/.autoupdate/npm_report/$repo.txt

      retVal=$?

      git add package-lock.json package.json &&
        git commit -m "Update NPM dependencies"

      if [ $retVal -ne 0 ]; then
        echo "ERROR UPDATING NPM ${repo}"
        cat $CLONE_LOCATION/.autoupdate/npm_report/$repo.txt
      fi
    fi
  fi

  if [[ -f '.autoupdate/postupdate' ]]; then
    .autoupdate/postupdate
    if [ $? -ne 0 ]; then
      continue
    fi
  fi

  if [ $retVal -eq 0 ]; then
    git push origin update-dependencies &&
      hub pull-request -f -m "Update dependencies"

    retVal=$?
    if [ $retVal -eq 0 ]; then
      if [[ -f 'Gemfile.lock' ]]; then
        GEM_SUCCESS_REPORTS_ARRAY+=("$CLONE_LOCATION/.autoupdate/gem_report/$repo.txt")
      fi

      if [[ -f 'yarn.lock' ]]; then
        YARN_SUCCESS_REPORTS_ARRAY+=("$CLONE_LOCATION/.autoupdate/yarn_report/$repo.txt")
      fi

      if [[ -f 'package-lock.json' ]]; then
        NPM_SUCCESS_REPORTS_ARRAY+=("$CLONE_LOCATION/.autoupdate/npm_report/$repo.txt")
      fi
    else
      echo "ERROR PUSHING ${repo}"
    fi
  fi

  echo " ===== "
done

cd $SCRIPT_PATH
./slack_bot.rb "Dependency Updates Shipped!"
./slack_bot.rb "`cat ${GEM_SUCCESS_REPORTS_ARRAY[*]} | grep "(was " | cut -f 2-5 -d " " | sort | uniq`"
