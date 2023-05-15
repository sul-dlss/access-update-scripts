pipeline {
  agent any

  triggers {
      cron('H 2 * * 1')
  }

  environment {
    SIDEKIQ_PRO_SECRET = credentials("sidekiq_pro_secret")
    ACCESS_TEAM_SLACK_API_TOKEN = credentials("access-team-slack-token")
    GH_ACCESS_TOKEN = credentials("sul-ci org token")
  }

  stages {
    stage('Infrastructure') {

      when {
        allOf {
          branch 'manual-infra-build';
          not { triggeredBy 'SCMTrigger' }
        }
      }

      steps {
        checkout scm

        sshagent (['sul-devops-team']){
          sh '''#!/bin/bash -l
          export PATH=/ci/home/bin:$PATH
          export HUB_CONFIG=/ci/home/config/hub
          export SLACK_DEFAULT_CHANNEL='#dlss-infrastructure'
          export REPOS_PATH=$WORKSPACE/infrastructure

          # Load RVM
          rvm use 3.2.2@infrastructure_dependency_updates --create
          gem install bundler
          bundle config set --local without 'production staging'
          bundle config --global gems.contribsys.com $SIDEKIQ_PRO_SECRET
          bundle update --bundler
          bundle install

          ./autupdate.sh

          bundle exec ./git_hub_links.rb
          '''
        }
      }
    }
  }
}
