#!/usr/bin/env ruby

require 'json'
require './slack_bot'

##
# This script uses the GitHub REST API to get find dependency update PRs for the configured
# repositories.
#
# This script can simply be run as "./git_hub_links.rb" or "ruby git_hub_links.rb"
#
# The GitHub REST API will rate limit you, but not before you would be able to run this script multiple times.
# If you run into rate limiting issues, you can generate a personal access token and pass it in using the GH_ACCESS_TOKEN env var,
# "GH_ACCESS_TOKEN=abc123 ./git_hub_links.rb"
# See https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/ for more info
class GitHubLinks
  def self.render
    new.render
  end

  def render
    SlackBot.new.message(text: slack_bot_content)
  end

  private

  def slack_bot_content
    repo_content = repos.map do |repo|
      pr, * = client.pull_requests(repo, head: "#{repo.split('/').first}:update-dependencies")

      "#{repo}\t#{pr && "#{pr[:html_url]}/files"}"
    end.map(&:to_s).join("\n")

    [
      '*Weekly dependency update time is here!*',
      "\nBelow you will find the content for our weekly dependency update spreadsheet",
      "```#{repo_content}```"
    ].join(' ')
  end

  def repos
    repos_file.to_a.map(&:strip).sort
  end

  def repos_file
    File.open("#{ENV['REPOS_PATH']}/projects")
  end

  def client
    @client ||= Octokit::Client.new(access_token: access_token)
  end

  def access_token
    ENV['GH_ACCESS_TOKEN']
  end
end

GitHubLinks.render
