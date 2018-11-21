#!/bin/bash

WORKSPACE=${WORKSPACE:-$TMPDIR}

cd $WORKSPACE
mkdir -p $WORKSPACE/.autoupdate
cd $WORKSPACE/.autoupdate

mkdir gem_report
mkdir npm_report

GEM_SUCCESS_REPORTS_ARRAY=("/dev/null")
NPM_SUCCESS_REPORTS_ARRAY=("/dev/null")

# Ruby / Rails applications
for i in purl stacks sul-embed purl-fetcher content_search course_reserves earthworks exhibits library_hours_rails sul-bento-app sul-directory sul-requests SearchWorks revs dlme arclight-demo vatican_exhibits revs-indexer-service bassi_veratti editstore-updater mods_display_app mirador_sul frda relevancy_dashboard stanford-arclight searchworks_traject_indexer; do
  echo $i
  cd $WORKSPACE/.autoupdate
  git clone git@github.com:sul-dlss/$i
  cd $i
  git fetch origin
  git checkout -B update-dependencies
  git reset --hard  origin/master
  bundle update > ../gem_report/$i.txt &&
    git add Gemfile.lock &&
    git commit -m "Update dependencies" &&
    git push origin update-dependencies &&
    hub pull-request -f -m "Update dependencies"

  retVal=$?

  if [ $retVal -ne 0 ]; then
    echo "ERROR UPDATING ${i}"
    cat ../gem_report/$i.txt
  else
    GEM_SUCCESS_REPORTS_ARRAY+=("../gem_report/$i.txt")
  fi

  echo " ===== "
done

# JavaScript applications
for i in searchworks-status; do
  echo $i
  cd $WORKSPACE/.autoupdate
  git clone git@github.com:sul-dlss/$i
  cd $i
  git fetch origin
  git checkout -B update-dependencies
  git reset --hard  origin/master

  npm audit fix > ../npm_report/$i.txt &&
  git add package-lock.json package.json &&
  git commit -m "Update dependencies" &&
  git push origin update-dependencies &&
  hub pull-request -f -m "Update dependencies"

  retVal=$?

  if [ $retVal -ne 0 ]; then
    echo "ERROR UPDATING ${i}"
    cat ../npm_report/$i.txt
  else
    NPM_SUCCESS_REPORTS_ARRAY+=("../npm_report/$i.txt")
  fi
done


echo "============"
echo "| Gems updated |"
echo "============"
cat ${GEM_SUCCESS_REPORTS_ARRAY[*]} | grep "(was " | cut -f 2-5 -d " " | sort | uniq
echo "============"
