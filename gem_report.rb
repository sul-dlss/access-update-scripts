major = []
minor = []
patch = []
repos_updated = []

# gem_report is a file of .txt files with Bundler output created by autupdate.sh
Dir.foreach('$TMPDIR/.autoupdate/gem_report') do |repo|
  next if (repo == '.') || (repo == '..') || (repo == '.DS_Store')

  repo_name = repo.chomp('.txt')
  puts "#{'*' * 20} #{repo_name} #{'*' * 20}"
  repos_updated << repo_name

  File.open("./gem_report/#{repo}", 'r') do |f|
    f.each_line do |line|
      matchd = /(?<gem_name>[\w-]*) (?<installed>[\w.]*) \(was (?<previous>[\w.]*)/.match(line)
      next if matchd.nil?

      p gem_name = matchd['gem_name']
      p matchd['previous']
      p matchd['installed']


      installed = /(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)/.match(matchd['installed'])
      previous = /(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)/.match(matchd['previous'])

      if installed['major'] > previous['major'] && !major.include?(gem_name)
        major << gem_name
        next
      end

      if installed['minor'] > previous['minor'] && !minor.include?(gem_name)
        minor << gem_name
        next
      end

      if installed['patch'] > previous['patch'] && !patch.include?(gem_name)
        patch << gem_name
        next
      end
    end
  end
end

# simple output
puts "#{'*' * 20} basic report #{'*' * 20}"
puts "Repos updated: #{repos_updated.join(',')}"
puts "Major: #{major.join(',')}"
puts "Minor: #{minor.join(',')}"
puts "Patch: #{patch.join(',')}"

# CSV
puts "#{'*' * 20} CSV #{'*' * 20}"
puts "major:\t #{major.join(',')}"
puts "minor:\t #{minor.join(',')}"
puts "patch:\t #{patch.join(',')}"

# Slackify
puts "#{'*' * 20} Slack report #{'*' * 20}"
major.map! { |repo| "`#{repo}`" }
minor.map! { |repo| "`#{repo}`" }
patch.map! { |repo| "`#{repo}`" }
puts "*major:* #{major.join(',')}"
puts "*minor:* #{minor.join(',')}"
puts "*patch:* #{patch.join(',')}"
