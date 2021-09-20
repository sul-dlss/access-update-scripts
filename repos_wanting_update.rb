#!/usr/bin/env ruby

# Usage:
# ./repos_wanting_update.rb infrastructure/projects.yml

file = ARGV[0]
if !file || !File.exists?(file)
  $stderr.puts("file not found")
  exit(1)
end

require 'yaml'
data = YAML.load_file(file)

puts data.fetch('projects').
  select { |project| project.fetch('update', true) }.
  map { |project| project.fetch('repo')}
