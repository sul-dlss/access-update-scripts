#!/usr/bin/env ruby

require 'json'
require './slack_bot'
require 'yaml'

##
# This script uses the GitHub REST API to get find dependency update PRs for the configured
# repositories.
#
# This script can simply be run as "./git_hub_links.rb" or "ruby git_hub_links.rb"
#
# The GitHub REST API will rate limit you, but not before you would be able to run this script multiple times.
# If you run into rate limiting issues, you can generate a personal access token and pass it in using the GH_ACCESS_TOKEN env var,
# "GH_ACCESS_TOKEN=abc123 REPOS_PATH=access ./git_hub_links.rb"
# See https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/ for more info
class GitHubLinks
  def self.render
    new.render
  end

  def render
    slack_bot_content.each do |text|
      SlackBot.new.message(text: text)
    end
  end

  private

  def slack_bot_content
    repo_content = repos.map do |repo|
      pr, * = client.pull_requests(repo, head: "#{repo.split('/').first}:update-dependencies")

      "#{repo}\t#{pr && "#{pr[:html_url]}/files"}"
    end.map(&:to_s)

    messages_text(repo_content)
  end

  def messages_text(repo_content)
    content_parts = [repo_content.slice(0..39), repo_content.slice(40..100)].compact
    content_parts.map { |content| "```\n#{content.join("\n")}```" }

    content_parts.prepend(
      ["*Weekly dependency update time is here!*\n",
       "Below you will find the content for our weekly dependency update spreadsheet\n"].join
    )
  end

  def repos
    data = YAML.load_file(repos_file)
    data.fetch('projects').
      select { |project| project.fetch('update', true) }.
      map { |project| project.fetch('repo')}.sort
  end

  def repos_file
    File.join(ENV['REPOS_PATH'], "projects.yml")
  end

  def client
    @client ||= Octokit::Client.new(access_token: access_token)
  end

  def access_token
    ENV['GH_ACCESS_TOKEN']
  end
end

GitHubLinks.render
