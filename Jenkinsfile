pipeline {
  agent any

  triggers {
      cron('H 6 * * 1')
  }

  environment {
    SIDEKIQ_PRO_SECRET = credentials("sidekiq_pro_secret")
  }

  stages {
    stage('Test') {
    
      when { expression { env.BRANCH_NAME == 'master' } }
      steps {
        checkout scm

        sshagent (['sul-devops-team']){
          sh '''#!/bin/bash -l
          export PATH=/ci/home/bin:$PATH
          export HUB_CONFIG=/ci/home/config/hub

          # Load RVM
          rvm use 2.5.3@access_dependency_updates --create
          gem install bundler

          bundle config --global gems.contribsys.com $SIDEKIQ_PRO_SECRET
          ./autupdate.sh
          '''
        }
      }
    }
  }
}

