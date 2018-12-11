// Paste this script in your browser console

// Enter GitHub search params @ https://github.com/pulls
// is:pr org:sul-dlss head:update-dependencies is:open
// example: https://github.com/pulls?utf8=✓&q=is%3Apr+org%3Asul-dlss+head%3Aupdate-dependencies+is%3Aopen+

// Repo order used in autupdate.sh and status table
// https://github.com/sul-dlss/access-update-scripts/blob/master/autupdate.sh
var repoList= "purl stacks sul-embed purl-fetcher content_search course_reserves earthworks exhibits library_hours_rails sul-bento-app sul-directory sul-requests SearchWorks revs dlme arclight-demo vatican_exhibits revs-indexer-service bassi_veratti editstore-updater mods_display_app mirador_sul frda relevancy_dashboard stanford-arclight searchworks-status searchworks_traject_indexer harvestdor-indexer"
repoList = repoList.split(' ')

// Retreive PR links
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
