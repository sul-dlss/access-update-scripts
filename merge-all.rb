#!/usr/bin/env ruby
# frozen_string_literal: true

# === Usage ===
#
# To generate update-dependencies PRs for all repos in <REPOS_PATH>/projects.yml:
#
#   $ REPOS_PATH=infrastructure GITHUB_TOKEN=abc123 ./merge-all.rb
#
# To generate PRs only for projects that rely on Cocina updates:
#
#   $ REPOS_PATH=infrastructure GITHUB_TOKEN=abc123 COCINA_LEVEL2= ./merge-all.rb
#
# NOTE: The above variables may also be set as environment variables instead, in
#       which case they will be picked up by the script without needing to be
#       passed in on the command line.

require 'highline/import'
require 'octokit'
require 'yaml'

REPOSITORIES_FILE = File.join(ENV.fetch('REPOS_PATH'), 'projects.yml')
COCINA_LEVEL2 = ENV['COCINA_LEVEL2']
BRANCH_NAME = ENV.fetch('BRANCH_NAME', 'update-dependencies')
COCINA_LEVEL2_BRANCH_NAME = ENV.fetch('COCINA_LEVEL2_BRANCH_NAME', 'cocina-level2-updates')

def access_token
  @access_token = ENV['GITHUB_TOKEN'] || ENV['GH_ACCESS_TOKEN']
  raise 'GITHUB_TOKEN variable must be set' if @access_token.nil? || @access_token.empty?

  @access_token
end

def projects
  @projects = YAML.load_file(REPOSITORIES_FILE).fetch('projects').select { |project| project.fetch('merge', true) }
end

# return all projects from the projects.yml file except those with `merge: false` set.
# further filter by `cocina_level2: true` if ENV variable set
def repo_entries
  return projects unless COCINA_LEVEL2

  projects.select { |project| project.fetch('cocina_level2', true) }
end

# @return [Array<Hash>] the update PR
def find_prs(client, entries)
  entries.filter_map do |entry|
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
      warn "404 checking branch protection for #{repo}: #{e}"
    end

    { repo: repo, number: pr.number, url: pr.html_url, status: status_from(statuses, checks) }
  end
end

def branch_name
  if COCINA_LEVEL2
    COCINA_LEVEL2_BRANCH_NAME
  else
    BRANCH_NAME
  end
end

def status_from(statuses, checks)
  # GitHub API marks PRs with 0 statuses as "pending", we cast that to success
  (statuses.state == 'success' || statuses.total_count.zero?) &&
    checks.check_runs.map(&:conclusion).all? { |status| status == 'success' }
end

client = Octokit::Client.new(access_token:)
pr_list = find_prs(client, repo_entries)

if pr_list.empty?
  puts 'No PRs were found'
  exit 1
end

unless pr_list.all? { |pr| pr[:status] }
  puts '*No* PRs were merged because these PRs are not passing: '
  pr_list.reject { |pr| pr[:status] }.each do |pr|
    puts "#{pr[:status]} - #{pr[:url]}"
  end
  exit 1
end

puts "All #{pr_list.size} of the update PRs are successful and ready to merge."
confirm = ask('Do it? [Y/N] ') { |yn| yn.limit = 1, yn.validate = /[yn]/i }
exit 0 unless confirm.downcase == 'y'

puts 'Merging:'

pr_list.each do |pr|
  puts pr[:url]
  client.create_pull_request_review(pr[:repo], pr[:number], body: 'Approved by automated merge script', event: 'APPROVE')
  client.merge_pull_request(pr[:repo], pr[:number], 'Merged by automated merge script')
end

exit 0
