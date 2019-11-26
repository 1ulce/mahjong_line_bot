Slack.configure do |config|
  config.token = ENV["SLACK_TOKEN"]
end

def slack_client
  @slack_client ||= Slack::Web::Client.new
end