require File.join(__dir__, 'boot')

settings = Application.settings

# Configure SQS Client
if Application.env == 'production'
  sqs_client = Aws::SQS::Client.new(region: 'us-east-1')
else
  credentials = Aws::Credentials.new(settings['aws_key'], settings['aws_secret'])
  sqs_client = Aws::SQS::Client.new(region: 'us-east-1', credentials: credentials)
end

poller = Aws::SQS::QueuePoller.new(settings['sqs_queue_url'], client: sqs_client)

poll_options = {max_number_of_messages: 10, skip_delete: true, wait_time_seconds: settings['polling_interval_seconds'], attribute_names: ['All']}

Application.logger.info('Started. Polling for messages')

poller.poll(poll_options) do |messages|
  messages.each do |message|
    message_handler = MessageHandler.new({message: message, sqs_client: sqs_client, settings: settings})
    message_handler.handle
  end
end
