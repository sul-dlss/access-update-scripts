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
          branch 'cocina-level2-updates';
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
          rvm use 3.3.1@infrastructure_dependency_updates --create
          gem install bundler
          bundle install --without production staging
          bundle config --global gems.contribsys.com $SIDEKIQ_PRO_SECRET
          GITHUB_TOKEN=$GH_ACCESS_TOKEN BUNDLE_GEMS__CONTRIBSYS__COM=$SIDEKIQ_PRO_SECRET bundle exec ./cocina_level2_prs.rb
          '''
        }
      }
    }
  }
}
