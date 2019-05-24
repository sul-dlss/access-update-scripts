#!/usr/bin/env ruby
# frozen_string_literal: true

###
# How to use this script
# From the command line run REPOS_PATH=./access ./outdated_report.rb
# By default this will clone all the repositories in the repo list,
# run the bundle outdated command, and return the data filtered by
# gems who have updates available but we've requested a version that may
# be preventing us from updating it.
#
# Since this data is modeled locally, it is possible to require this file
# (after commenting out the last line that causes the script to run) and
# do other useful things compare installed vs newest versions to report
# on all major or non-major version upgrades, etc.
###

##
# List of projects
class Projects
  def self.call
    File.open("#{ENV['REPOS_PATH']}/ruby").readlines.map(&:chomp)
  end
end

##
# Model the bundle outdated return data to get at the various pieces of the string
class OutdatedData
  MATCH_REGEX = /^(?<gem>\S+) \((?<updates>.*)\)( in groups "(?<groups>.*)")?/.freeze

  attr_reader :content
  def initialize(content)
    @content = content
  end

  def to_s
    content
  end

  def gem
    matched_content[:gem]
  end

  def newest
    updates[0].split(' ')[1]
  end

  def installed
    updates[1].split(' ')[1]
  end

  def requested
    _, *rest = (updates[2] || '').split(' ')
    rest.join(' ')
  end

  def groups
    (matched_content[:groups] || '').split(', ')
  end

  private

  def updates
    matched_content[:updates].split(', ')
  end

  def matched_content
    content.match(MATCH_REGEX)
  end
end

##
# Download list of projects and return all the bundle outdated output by project
class DownloadAndRunOutdated
  def self.call
    new.download_all_and_cache_outdated.cache
  end

  TEMP_DIR = '/tmp'
  attr_reader :projects
  def initialize(projects: Projects.call)
    @projects = projects
  end

  def cache
    @cache ||= {}
  end

  def download_all_and_cache_outdated
    projects.map do |project|
      project_dir = "#{TEMP_DIR}/outdated_reports/#{project}"
      download_or_update(project, project_dir)

      capture = `cd #{project_dir} && bundle outdated`.split("\n")
      cache[project] = capture.map do |line|
        next unless line.start_with?('  * ')

        OutdatedData.new(line.sub('  * ', ''))
      end.compact
    end

    self
  end

  def download_or_update(project, directory)
    if Dir.exist?(directory)
      `cd #{directory} && git fetch --all && git reset --hard origin/master`
    else
      `git clone git@github.com:sul-dlss/#{project} #{directory}`
    end
  end
end

##
# Print out outdated data filtered by
# the gems that have been requested
class OutdatedByRequest
  attr_reader :data
  def initialize(data = DownloadAndRunOutdated.call)
    @data = data
  end

  def self.call
    new.data.each do |project, updates|
      puts project
      updates.each do |update|
        next if update.requested.empty?

        puts "\t#{update}"
      end
    end
  end
end

OutdatedByRequest.call
