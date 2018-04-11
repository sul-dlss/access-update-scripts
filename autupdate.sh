#!/bin/bash

cd $TMPDIR
mkdir -p $TMPDIR/.autoupdate
cd $TMPDIR/.autoupdate
for i in purl stacks sul-embed purl-fetcher content_search course_reserves discovery-dispatcher earthworks exhibits library_hours_rails sul-bento-app sul-directory sul-requests sw-indexer SearchWorks revs dlme arclight-demo vatican_exhibits revs-indexer-service bassi_veratti editstore-updater portfolios mods_display_app mirador_sul; do
  echo $i
  cd $TMPDIR/.autoupdate
  git clone git@github.com:sul-dlss/$i
  cd $i
  git fetch origin
  git checkout -B update-dependencies
  git reset --hard  origin/master
  bundle update &&
  git add Gemfile.lock &&
  git commit -m "Update dependencies" &&
  git push origin update-dependencies &&
  hub pull-request -f -m "Update dependencies"
done