// Paste this script in your browser console

// PR search at https://github.com/pulls
// is:pr org:sul-dlss head:update-dependencies created:2018-05-08..2018-05-09

// Repo order used in our update script and status table
// https://github.com/sul-dlss/access-update-scripts/blob/master/infrastructure/ruby
var repoList= "argo common-accessioning dlme dlme-transform dor-services-app dor_indexing_app dor-fetcher-service gis-robot-suite google-books hydra_etd hydrus lyberservices-scripts modsulator-app-rails pre-assembly preservation_catalog preservation_robots repository-api rialto-etl rialto-webapp robot-console sdr-services-app sul_pub suri_rails was-registrar-app was_robot_suite was-thumbnail-service workflow-server-rails"
repoList = repoList.split(' ')

// Retrieve PR links
var elements = Array.from(document.getElementsByClassName('js-navigation-open'))
var links = []
links = elements.filter(element => element.text.search("dependencies") > 0)
links = links.map((link) => link.href + '/files')

// Make a hash of repo name : PR link pairs
var pairs = {}
links.forEach((value) => {
    pairs[value.split('/')[4]] = value
})

// Compose a copy n' paste-able table of repo names with either PR links OR empty cells
var prettyTable = []
repoList.forEach((repo) => {if (pairs[repo]){
  prettyTable.push(`${repo}\t${pairs[repo]}`)
} else {
  prettyTable.push(`${repo}\t `)
}})

// join with new lines
prettyTable.join('\n')
