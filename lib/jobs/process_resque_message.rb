require File.join(__dir__, '..', 'resque_message_handler')
require File.join(__dir__, '..', '..', 'boot')
require 'json'

# The Resque job that does all the actual handling of the message
class ProcessResqueMessage
  @queue = :work_immediately

  # message a JSON string of the original SQS message body
  def self.perform(message)
    Application.logger.info("Processing a message from SQS", original_message: message)
    parsed_message = JSON.parse(message)
    resque_message_handler = ResqueMessageHandler.new(settings: Application.settings, message: parsed_message)
    resque_message_handler.handle
  end

end
