#!/usr/bin/env ruby
# frozen_string_literal: true

# To use this script, you must
#  - install "hub" on your local machine:  https://hub.github.com/
#  - have a github access token with scopes of "read:org" and "repo"
#  (see https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
#
# Usage:
# "GITHUB_TOKEN=abc123 ./cocina_level2_prs.rb

# Cocina Level 2 updates are infrastructure apps that need to be updated after
#   cocina-models gem new release
#   and after dor-services-client, sdr-client gems new release
#   and after dor-services-app, sdr-api updated (and api updated)
require 'yaml'
require 'bundler/setup'
require 'open3'
require 'fileutils'

$LOAD_PATH.unshift 'lib'
require 'error_emitting_executor'

WORK_DIR = 'tmp/repos'
BRANCH_NAME = 'cocina-level2-updates'
GIT_MAIN_FETCH_REFS = '+refs/heads/main:refs/remotes/origin/main'
GIT_BRANCH_FETCH_REFS = GIT_MAIN_FETCH_REFS.gsub('main', BRANCH_NAME).freeze
COMMIT_DESCRIPTION = 'Update dependencies for cocina-models update'
# the message depends on the locally installed version of git
EXPECTED_PUSH_MESSAGES = [
  "Branch '#{BRANCH_NAME}' set up to track remote branch '#{BRANCH_NAME}' from 'origin'",
  "branch '#{BRANCH_NAME}' set up to track 'origin/#{BRANCH_NAME}'."
]

def repos_file
  File.join 'infrastructure', 'projects.yml'
end

# @return [Array<String>] the git repos that need cocina level2 updates
def repos
  YAML.load_file(repos_file).fetch('projects')
      .select { |project| project.fetch('cocina_level2', true) }
      .map { |project| project.fetch('repo') }
end

def create_prs(repos)
  repos.map do |repo|
    pr_link = prepare_and_create_pr(repo)
    # Print out pr_link to let the user know what it's doing
    puts pr_link
    { repo: repo, pr_link: pr_link }
  end
end

def prepare_and_create_pr(repo)
  clone_or_update_repo(repo)

  within_cloned_repo_dir(repo) do
    result = create_branch
    result = update_gems unless result_failure?('create_branch', result)
    result = local_git_commit unless result_failure?('update_gems', result)
    result = git_push_origin unless result_failure?('local_git_commit', result)
    create_pr if EXPECTED_PUSH_MESSAGES.find { |msg| result.include?(msg) }
  end
end

# must be called as part of the block for within_cloned_repo_dir(repo)
def create_branch
  ErrorEmittingExecutor.execute("git checkout -B #{BRANCH_NAME}")

  # Ensure local branch matches any existing upstream branch; will reset to HEAD by default
  ErrorEmittingExecutor.execute('git reset --hard', exit_on_error: true)
end

# must be called as part of the block for within_cloned_repo_dir(repo)
def update_gems
  gemfile = File.read('Gemfile')
  included_gems = %w[cocina-models dor-services-client sdr-client dor_indexing].filter { |gem_name| gemfile.include?(gem_name)}
  ErrorEmittingExecutor.execute("bundle update --conservative #{included_gems.join(' ')}") unless included_gems.empty?
end

# must be called as part of the block for within_cloned_repo_dir(repo)
def local_git_commit
  ErrorEmittingExecutor.execute("git commit -m '#{COMMIT_DESCRIPTION}' Gemfile.lock")
end

# must be called as part of the block for within_cloned_repo_dir(repo)
def git_push_origin
  ErrorEmittingExecutor.execute("git push origin -u #{BRANCH_NAME}")
end

# must be called as part of the block for within_cloned_repo_dir(repo)
def create_pr
  ErrorEmittingExecutor.execute("hub pull-request -f -m '#{COMMIT_DESCRIPTION}'")
end

# Check the result string of ErrorEmittingExecutor command for failure,
#   output a message if so
def result_failure?(step_name, result)
  if result == 'FAILED'
    p "stopped after #{step_name} due to failure"
    return true
  end
  false
end

def clone_or_update_repo(repo)
  puts "\n**** Processing #{repo} ****"
  if File.exist?(cloned_repo_dir(repo))
    update_repo(repo)
  else
    create_repo(repo)
  end
end

def update_repo(repo)
  within_cloned_repo_dir(repo) do
    fetch_update
    # This allows our default branches to vary across projects
    ErrorEmittingExecutor.execute('git reset --hard $(git symbolic-ref refs/remotes/origin/HEAD)',
                                  exit_on_error: true)
    ErrorEmittingExecutor.execute('bundle install', exit_on_error: true)
  end
end

# fetch main and our latest branch from origin if it exists
# must be called as part of the block for within_cloned_repo_dir(repo)
def fetch_update
  remote_branch = ErrorEmittingExecutor.execute("git branch -r --list origin/#{BRANCH_NAME}")
  if remote_branch == 'origin/cocina-level2-updates'
    ErrorEmittingExecutor.execute("git fetch origin #{GIT_MAIN_FETCH_REFS} #{GIT_BRANCH_FETCH_REFS}")
  else
    ErrorEmittingExecutor.execute("git fetch origin #{GIT_MAIN_FETCH_REFS}", exit_on_error: true)
  end
end

def create_repo(repo)
  FileUtils.mkdir_p(cloned_repo_dir(repo))
  puts "**** Creating #{cloned_repo_dir(repo)}"
  within_cloned_repo_dir(repo) do
    ErrorEmittingExecutor.execute("git clone --depth=5 git@github.com:#{repo}.git .", exit_on_error: true)
    ErrorEmittingExecutor.execute('bundle install', exit_on_error: true)
  end
end

def within_cloned_repo_dir(repo, &block)
  Dir.chdir(cloned_repo_dir(repo)) do
    # Execute commands in the project-specific bundler context, rather
    #   than access-update-scripts' bundler context.
    Bundler.with_unbundled_env do
      block.call
    end
  end
end

def cloned_repo_dir(repo)
  File.join(WORK_DIR, repo)
end

## Actual Script Below

begin
  pr_list = create_prs(repos)
  puts "\n********** Summary **********"

  if pr_list.all? { |result| result[:pr_link].nil? || result[:pr_link].empty? }
    puts 'No PRs were created.'
    puts '********** End Summary **********'
    exit(1)
  end

  if pr_list.any? { |result| result[:pr_link].nil? || result[:pr_link].empty? }
    puts '*Some* PRs were not created: '
    pr_list
      .select { |result| result[:pr_link].nil? || result[:pr_link].empty? }
      .each do |result|
      puts "#{result[:repo]} did NOT create a PR for updated cocina gems."
      puts '********** End Summary **********'
    end
    exit(1)
  end

  puts "All #{pr_list.size} of the cocina gem update PRs were created successfully."
  pr_list.each { |result| puts "  #{result[:pr_link]}" }

  puts '********** End Summary **********'
end
