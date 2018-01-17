require 'aws-sdk'
require File.join(__dir__, 'lib', 'barcode_to_customer_code_mapper')

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
    parsed_message = JSON.parse(message.body)
    mapper = BarcodeToCustomerCodeMapper.new({barcodes: parsed_message['barcodes'], api_url:  settings['scsb_api_url'], api_key: settings['scsb_api_key']})
    puts "MAPPING of barcodes to customerCodes: #{mapper.barcode_to_customer_code_mapping}"
  end
end
