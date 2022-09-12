pipeline {
  agent any

  triggers {
      cron('H 2 * * 1')
  }

  environment {
    SIDEKIQ_PRO_SECRET = credentials("sidekiq_pro_secret")
    GH_ACCESS_TOKEN = credentials("sul-ci org token")
  }

  stages {
    stage('Infrastructure') {

      when {
        allOf {
          branch 'kick-infra-libsys-builds';
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
          export SLACK_DEFAULT_CHANNEL='#dlss-infrastructure'
          export REPOS_PATH=$WORKSPACE/infrastructure

          # Load RVM
          rvm use 3.0.3@infrastructure_dependency_updates --create
          gem install bundler
          bundle install --without production staging

          bundle config --global gems.contribsys.com $SIDEKIQ_PRO_SECRET
          ./autupdate.sh
          '''
        }
      }
    }

    stage('Libsys') {

      when {
        allOf {
          branch 'kick-infra-libsys-builds';
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
          '''
        }
      }
    }
  }
}
