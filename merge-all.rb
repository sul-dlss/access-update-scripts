#!/usr/bin/env ruby

# Usage:
# "REPOS_PATH=infrastructure GH_ACCESS_TOKEN=abc123 ./merge-all.rb"
BRANCH_NAME = 'update-dependencies'

def repos_file
  File.open("#{ENV['REPOS_PATH']}/projects")
end

def repos
  repos_file.readlines(chomp: true)
end

# @return [Array<Hash>] the update PR
def find_prs(client, repos)
  repos.map do |repo|
    pr, * = client.pull_requests(repo, head: "#{repo.split('/').first}:#{BRANCH_NAME}")

    unless pr
      warn "no #{BRANCH_NAME} pr found for #{repo}"
      next
    end
    puts "#{BRANCH_NAME} pr found for #{repo}"
    statuses = client.combined_status(repo, pr.head.sha)
    checks = client.check_runs_for_ref(repo, pr.head.sha, accept: Octokit::Preview::PREVIEW_TYPES[:checks])

    begin
      branch_protection = client.branch_protection(repo, pr.base.ref, accept: Octokit::Preview::PREVIEW_TYPES[:branch_protection])
      warn "No branch branch_protection is set up for #{repo}" unless branch_protection
    rescue Octokit::NotFound => e
      warn "404 checking branch protection for #{repo}? #{e}"
    end

    { repo: repo, number: pr.number, url: pr.html_url, status: status_from(statuses, checks) }
  end.compact
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

require 'octokit'
client = Octokit::Client.new(access_token: access_token)
pr_list = find_prs(client, repos)

if pr_list.empty?
  puts "No PRs were found"
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
confirm = ask("Do it? [Y/N] ") { |yn| yn.limit = 1, yn.validate = /[yn]/i }
exit unless confirm.downcase == 'y'

puts "Merging:"

pr_list.each do |pr|
  puts pr[:url]
  client.create_pull_request_review(pr[:repo], pr[:number], body: 'Approved by automated merge script', event: 'APPROVE')
  client.merge_pull_request(pr[:repo], pr[:number], 'Merged by automated merge script')
end
