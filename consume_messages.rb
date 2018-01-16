require 'aws-sdk'

# Bring environment variables in ./config/.env into scope.
# This is probably only used in development.
require 'dotenv'
Dotenv.load(File.join('.', 'config', '.env'))

# Create a hash that contains the configuarable variables
require 'erb'
require 'yaml'
path_to_settings = File.join(__dir__, "config", "settings.yml")
settings = YAML.load(ERB.new(File.read(path_to_settings)).result)

# Configure SQS Client
credentials = Aws::Credentials.new(settings['aws_key'], settings['aws_secret'])
sqs_client  = Aws::SQS::Client.new(region: 'us-east-1', credentials: credentials)
poller      = Aws::SQS::QueuePoller.new(settings['sqs_queue_url'], client: sqs_client)

poll_options = {max_number_of_messages: 10, skip_delete: true, wait_time_seconds: settings['polling_interval_seconds'], attribute_names: ['All']}

poller.poll(poll_options) do |messages|
  messages.each do |message|
    puts "Message body: #{message.body} with attributes #{message.attributes} and user_attributes of #{message.message_attributes}\n"
  end

end
