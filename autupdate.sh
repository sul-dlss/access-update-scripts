#!/bin/bash

SCRIPT_PATH=$(cd "$(dirname "$0")" ; pwd -P)
REPOS_FILE="${REPOS_PATH:-$SCRIPT_PATH}/projects"

CLONE_LOCATION=${WORKSPACE:-$TMPDIR}

cd $CLONE_LOCATION
mkdir -p $CLONE_LOCATION/.autoupdate
cd $CLONE_LOCATION/.autoupdate

mkdir gem_report
mkdir npm_report

GEM_SUCCESS_REPORTS_ARRAY=("/dev/null")
NPM_SUCCESS_REPORTS_ARRAY=("/dev/null")

# Ruby / Rails applications
while IFS='/' read -r org repo || [[ -n "$repo" ]]; do
  retVal=-1

  echo "$org/$repo"
  cd $CLONE_LOCATION/.autoupdate
  git clone git@github.com:$org/$repo
  cd $repo
  git fetch origin
  git checkout -B update-dependencies
  git reset --hard origin/master

  if [[ -f '.autoupdate/preupdate' ]]; then
    .autoupdate/preupdate
    if [ $? -ne 0 ]; then
      continue
    fi
  fi

  if [[ -f '.autoupdate/update' ]]; then
    .autoupdate/update
  else
    if [[ -f 'Gemfile.lock' ]]; then
      bundle update > $CLONE_LOCATION/.autoupdate/gem_report/$repo.txt &&
        git add Gemfile.lock &&
        git commit -m "Update dependencies" &&

      retVal=$?

      if [ $retVal -ne 0 ]; then
        echo "ERROR UPDATING ${repo}"
        cat $CLONE_LOCATION/.autoupdate/gem_report/$repo.txt
      fi
    fi

    if [[ -f 'package-lock.json' ]]; then
      npm update > $CLONE_LOCATION/.autoupdate/npm_report/$repo.txt &&
      npm audit fix > $CLONE_LOCATION/.autoupdate/npm_report/$repo.txt &&
      git add package-lock.json package.json &&
      git commit -m "Update dependencies"

      retVal=$?

      if [ $retVal -ne 0 ]; then
        echo "ERROR UPDATING ${repo}"
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

      if [[ -f 'package-lock.json' ]]; then
        NPM_SUCCESS_REPORTS_ARRAY+=("$CLONE_LOCATION/.autoupdate/npm_report/$repo.txt")
        end
      fi
    else
      echo "ERROR PUSHING ${repo}"
    fi
  fi

  echo " ===== "
done < $REPOS_FILE

cd $SCRIPT_PATH
./slack_bot.rb "Dependency Updates Shipped!"
./slack_bot.rb "`cat ${GEM_SUCCESS_REPORTS_ARRAY[*]} | grep "(was " | cut -f 2-5 -d " " | sort | uniq`"
