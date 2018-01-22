require 'aws-sdk'
require File.join(__dir__, 'lib', 'barcode_to_customer_code_mapper')
require File.join(__dir__, 'lib', 'scsbxml_fetcher')

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
    if parsed_message['action'] && parsed_message['action'] == 'sync'
      mapper = BarcodeToCustomerCodeMapper.new({barcodes: parsed_message['barcodes'], api_url:  settings['scsb_api_url'], api_key: settings['scsb_api_key']})
      mapping = mapper.barcode_to_customer_code_mapping
      puts "MAPPING of barcodes to customerCodes: #{mapping}"
      xml_fetcher = SCSBXMLFetcher.new({
        oauth_key:    settings['nypl_oauth_key'],
        oauth_url:    settings['nypl_oauth_url'],
        oauth_secret: settings['nypl_oauth_secret'],
        platform_api_url: settings['platform_api_url'],
        barcode_to_customer_code_mapping: mapping
      })
      boop = xml_fetcher.translate_to_scsb_xml
      puts "This will have #{boop.keys.length} keys"
      puts boop
    else
      puts 'log an error and delete this message'
    end
  end
end
