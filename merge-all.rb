#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage:
#   for update-dependencies PRs for all repos in (team)/projects.yml
# "REPOS_PATH=infrastructure GH_ACCESS_TOKEN=abc123 ./merge-all.rb"
#
#   for infrastructure cocina-level2 PRs only
#     note that COCINA_LEVEL2= is sufficient to be interpreted as true
# "REPOS_PATH=infrastructure GH_ACCESS_TOKEN=abc123 COCINA_LEVEL2= ./merge-all.rb"
BRANCH_NAME = 'update-dependencies'
COCINA_LEVEL2_BRANCH_NAME = 'cocina-level2-updates'

require 'yaml'

def repos_file
  File.join ENV['REPOS_PATH'], 'projects.yml'
end

# return all projects from the project.yml file except those with merge: false set
#  further filter by cocina_level2: true if ENV file set
def repo_entries
  projects = YAML.load_file(repos_file).fetch('projects')
                 .select { |project| project.fetch('merge', true) }

  return projects unless cocina_level2

  projects.select { |project| project.fetch('cocina_level2', true) }
end

# @return [Array<Hash>] the update PR
def find_prs(client, entries)
  entries.map do |entry|
    repo = entry.fetch('repo')
    pr, * = client.pull_requests(repo, head: "#{repo.split('/').first}:#{branch_name}")

    unless pr
      warn "no #{branch_name} pr found for #{repo}"
      next
    end
    puts "#{branch_name} pr found for #{repo}"
    statuses = client.combined_status(repo, pr.head.sha)
    checks = client.check_runs_for_ref(repo, pr.head.sha)

    begin
      branch_protection = client.branch_protection(repo, pr.base.ref)
      warn "No branch protection is set up for #{repo}" unless branch_protection
    rescue Octokit::NotFound => e
      warn "404 checking branch protection for #{repo}? #{e}"
    end

    { repo: repo, number: pr.number, url: pr.html_url, status: status_from(statuses, checks) }
  end.compact
end

def branch_name
  if cocina_level2
    COCINA_LEVEL2_BRANCH_NAME
  else
    BRANCH_NAME
  end
end

def status_from(statuses, checks)
  # GitHub API marks PRs with 0 statuses as "pending", we cast that to success
  return 'success' if (statuses.state == 'success' || statuses.total_count.zero?) &&
                      checks.check_runs.map(&:conclusion).all? { |status| status == 'success' }

  'failure'
end

def access_token
  ENV['GH_ACCESS_TOKEN']
end

# anything other than nil or false is true here, just as Ruby intended
def cocina_level2
  ENV['COCINA_LEVEL2']
end

require 'octokit'
client = Octokit::Client.new(access_token: access_token)
pr_list = find_prs(client, repo_entries)

if pr_list.empty?
  puts 'No PRs were found'
  exit
end

unless pr_list.all? { |pr| pr[:status] == 'success' }
  puts '*No* PRs were merged because these PRs are not passing: '
  pr_list.filter { |pr| pr[:status] != 'success' }.each do |pr|
    puts "#{pr[:status]} - #{pr[:url]}"
  end
  exit
end

puts "All #{pr_list.size} of the update PRs are successful and ready to merge."
require 'highline/import'
confirm = ask('Do it? [Y/N] ') { |yn| yn.limit = 1, yn.validate = /[yn]/i }
exit unless confirm.downcase == 'y'

puts 'Merging:'

pr_list.each do |pr|
  puts pr[:url]
  client.create_pull_request_review(pr[:repo], pr[:number], body: 'Approved by automated merge script', event: 'APPROVE')
  client.merge_pull_request(pr[:repo], pr[:number], 'Merged by automated merge script')
end
