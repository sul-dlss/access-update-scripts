# Dependency Update Scripts

We run dependency updates for Ruby and JavaScript projects once a week via SUL CI. The script can also be run locally as necessary (e.g. security patches).

## The Process

### Phase 1: Script
Jenkins run the script and PRs are created via the `sul-devops-team` account. If a pre-existing PR with the title `update-dependencies` is open, a PR is not created. Builds are triggered by the following scenarios:
- Monday morning before business hours
- A PR in `access-update-scripts` is merged into master
  - To kill unnecessary builds: Navigate from SUL CI ➡️ Stanford University Digital Library ➡️ access-update-scripts ➡️ Branches / master ➡️ Build History ➡️ Cancel build button (🆇)

### Phase 2: Reporting
A gem version report will be sent to the #dlss-access-team slack channel.  The output of the messages can be used to populate the team tracking spreadsheet with links to the PRs.

### Phase 3: Team Review
Devs tag team on reviewing and merging PRs. Manual remediation of PRs may be necessary.

### Phase 4: Deployment
After PRs are merged, devs will deploy to all available project environments (dev, stage, uat, prod etc.) unless the project requires release notes and internal communication.

## Modifying scripts
Secrets need to be configured via the Jenkins UI. Once configured there, they need to be added to the Jenkinsfile. Build triggers are also configured via Jenkinsfile.

## Requirements for running the script locally
- [hub](https://hub.github.com/)
- Bundler
- sidekiq pro key (for exhibits only)
