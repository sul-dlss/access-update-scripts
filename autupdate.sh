#!/bin/bash

SCRIPT_PATH=$(cd "$(dirname "$0")" ; pwd -P)
RUBY_REPOS_FILE="${WORKSPACE:-$SCRIPT_PATH}/repos/ruby"
JS_REPOS_FILE="${WORKSPACE:-$SCRIPT_PATH}/repos/javascript"

WORKSPACE=${WORKSPACE:-$TMPDIR}

cd $WORKSPACE
mkdir -p $WORKSPACE/.autoupdate
cd $WORKSPACE/.autoupdate

mkdir gem_report
mkdir npm_report

GEM_SUCCESS_REPORTS_ARRAY=("/dev/null")
NPM_SUCCESS_REPORTS_ARRAY=("/dev/null")

# Ruby / Rails applications
while IFS='' read -r repo || [[ -n "$repo" ]]; do
  echo $repo
  cd $WORKSPACE/.autoupdate
  git clone git@github.com:sul-dlss/$repo
  cd $repo
  git fetch origin
  git checkout -B update-dependencies
  git reset --hard  origin/master
  bundle update > ../gem_report/$repo.txt &&
    git add Gemfile.lock &&
    git commit -m "Update dependencies" &&
    git push origin update-dependencies &&
    hub pull-request -f -m "Update dependencies"

  retVal=$?

  if [ $retVal -ne 0 ]; then
    echo "ERROR UPDATING ${repo}"
    cat ../gem_report/$repo.txt
  else
    GEM_SUCCESS_REPORTS_ARRAY+=("../gem_report/$repo.txt")
  fi

  echo " ===== "
done < $RUBY_REPOS_FILE

# JavaScript applications
while IFS='' read -r repo || [[ -n "$repo" ]]; do
  echo $repo
  cd $WORKSPACE/.autoupdate
  git clone git@github.com:sul-dlss/$repo
  cd $repo
  git fetch origin
  git checkout -B update-dependencies
  git reset --hard  origin/master

  npm audit fix > ../npm_report/$repo.txt &&
  git add package-lock.json package.json &&
  git commit -m "Update dependencies" &&
  git push origin update-dependencies &&
  hub pull-request -f -m "Update dependencies"

  retVal=$?

  if [ $retVal -ne 0 ]; then
    echo "ERROR UPDATING ${repo}"
    cat ../npm_report/$repo.txt
  else
    NPM_SUCCESS_REPORTS_ARRAY+=("../npm_report/$repo.txt")
  fi
done < $JS_REPOS_FILE


echo "============"
echo "| Gems updated |"
echo "============"
cat ${GEM_SUCCESS_REPORTS_ARRAY[*]} | grep "(was " | cut -f 2-5 -d " " | sort | uniq
echo "============"
