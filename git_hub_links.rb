#!/usr/bin/env ruby

require 'json'
require './slack_bot'
##
# This script uses the GitHub REST API to get find dependency update PRs for the configured
# reqositories.
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
      PullRequest.new(repo)
    end.map(&:to_s).join("\n")

    [
      '*Weekly dependency update time is here!*',
      "\nBelow you will find the content for our weekly dependency update spreadsheet",
      "```#{repo_content}```"
    ].join(' ')
  end

  def repos
    [js_repos_file, ruby_repos_file].map(&:to_a).flatten.map(&:strip).sort
  end

  def js_repos_file
    File.open("#{ENV['REPOS_PATH']}/javascript")
  end

  def ruby_repos_file
    File.open("#{ENV['REPOS_PATH']}/ruby")
  end

  ##
  # Responsible for fetching the dependency update PR for a given proejct
  #
  class PullRequest
    attr_reader :repo
    def initialize(repo)
      @repo = repo
    end

    def to_s
      "#{repo}\t#{files_url}"
    end

    def files_url
      return "(🔒) #{repo_pr_search_url}" if data['message'] == 'Not Found' # Private repo
      return ' ' unless data['html_url'] # No dependency update PRs

      "#{data['html_url']}/files"
    end

    private

    def data
      if json.is_a?(Array)
        json.first || {}
      else
        if json['message'].start_with?('API rate limit exceeded')
          raise(
            StandardError,
            "\n\n😅 Oops! Looks like you've exceeded the API rate limit.\n" \
            "You may have run this script several times. You can continue to use this\n" \
            "script but you'll need to generate an access token and re-run with GH_ACCESS_TOKEN.\n" \
            "See https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/ for more info"
          )
        end
        json
      end
    end

    def json
      @json ||= JSON.parse(`curl -s #{pull_request_api_url}`)
    end

    def pull_request_api_url
      addl_params = "\\&access_token\\=#{access_token}" if access_token
      "https://api.github.com/repos/sul-dlss/#{repo}/pulls\\?head\\=sul-dlss:update-dependencies#{addl_params}"
    end

    def access_token
      ENV['GH_ACCESS_TOKEN']
    end

    def repo_pr_search_url
      "https://github.com/sul-dlss/#{repo}/pulls?q=is:pr%20update-dependencies%20is:open"
    end
  end
end

GitHubLinks.render
