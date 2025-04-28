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
    stage('Access') {

      when {
        allOf {
          branch 'main';
          not { triggeredBy 'SCMTrigger' }
        }
      }

      steps {
        checkout scm

        sshagent (['sul-devops-team']){
          sh '''#!/bin/bash -l
          source /opt/rh/devtoolset-6/enable

          export PATH=/ci/home/bin:$PATH
          export HUB_CONFIG=/ci/home/config/hub
          export REPOS_PATH=$WORKSPACE/access

          # Load RVM
          rvm use 3.4.1@access_dependency_updates --create
          gem install bundler
          bundle install

          bundle config --global gems.contribsys.com $SIDEKIQ_PRO_SECRET
          ./autupdate.sh

          bundle exec ./git_hub_links.rb
          '''
        }
      }
    }

    stage('Infrastructure') {

      when {
        allOf {
          branch 'main';
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
          rvm use 3.4.1@infrastructure_dependency_updates --create
          gem install bundler
          bundle install --without production staging

          bundle config --global gems.contribsys.com $SIDEKIQ_PRO_SECRET
          ./autupdate.sh

          bundle exec ./git_hub_links.rb terse
          '''
        }
      }
    }

    stage('Libsys') {

      when {
        allOf {
          branch 'main';
          not { triggeredBy 'SCMTrigger' }
        }
      }

      steps {
        checkout scm

        sshagent (['sul-devops-team']){
          sh '''#!/bin/bash -l
          source /opt/rh/devtoolset-6/enable
          export PATH=/ci/home/bin:$PATH
          export HUB_CONFIG=/ci/home/config/hub
          export SLACK_DEFAULT_CHANNEL='#libsys'
          export REPOS_PATH=$WORKSPACE/libsys

          # Load RVM
          rvm use 3.1.2@libsys_dependency_updates --create
          gem install bundler
          bundle install --without production staging

          bundle config --global gems.contribsys.com $SIDEKIQ_PRO_SECRET
          ./autupdate.sh

          bundle exec ./git_hub_links.rb
          '''
        }
      }
    }
  }
}
