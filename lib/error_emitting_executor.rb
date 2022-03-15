# frozen_string_literal: true

require 'open3'

# Service class for executing commands and barfing on errors
# @return [String] - returns 'FAILED' if command fails, whatever was stdout if it succeeds
class ErrorEmittingExecutor
  def self.execute(command, exit_on_error: false)
    out, err, status = Open3.capture3(ENV.slice('BUNDLE_GEMS__CONTRIBSYS__COM'), command)
    return out if status.success?

    p "Error executing '#{command}': '#{err} #{out}'"
    exit(1) if exit_on_error

    'FAILED'
  end
end
