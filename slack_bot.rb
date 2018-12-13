#!/usr/bin/env ruby

require 'bundler'
Bundler.require(:default)

##
# A simple SlackBot to send messages to slack channels w/ useful information
# Simpl call SlackBot.new.message(text: 'Howdy Access Team! :moose:')
class SlackBot
  def message(channel: default_channel, as_user: true, text:)
    client.chat_postMessage(channel: channel, as_user: as_user, text: text)
  end

  private

  def default_channel
    '#dlss-access-team'
  end

  def client
    @client ||= ::Slack::Web::Client.new(
      token: ENV['ACCESS_TEAM_SLACK_API_TOKEN']
    )
  end
end

# Allow the SlackBot to be called from the command line.
# Will join any arguments passed as a new line delimited message
# Example:
# ./slack_bot.rb "Hello Team!" "Hope all is well." Goodbye
SlackBot.new.message(text: ARGV.join("\n")) if ARGV.any?
