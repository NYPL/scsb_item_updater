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

response = sqs_client.receive_message(queue_url: settings['sqs_queue_url'], attribute_names: ['All'])

# Each message is an instance of:
# https://docs.aws.amazon.com/sdkforruby/api/Aws/SQS/Types/Message.html
response.messages.each do |message|
  puts message.body
end


# Polling is probably what we REALLY want to do although we need
# to avoid the default configuration which deletes messages at the
# end of the poll.

# https://docs.aws.amazon.com/sdkforruby/api/Aws/SQS/QueuePoller.html
# poller = Aws::SQS::QueuePoller.new(settings['sqs_queue_url'])
#
# poller.poll({max_number_of_messages: 10}) do |messages|
#   messages.each do |message|
#     puts "Message body: #{message.body}"
#   end
# end
