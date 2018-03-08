require File.join(__dir__, '..', 'resque_message_handler')
require File.join(__dir__, '..', '..', 'boot')
require 'json'

class RetriedResqueMessage
  @queue = :retrying

  def self.perform(options)
    Application.logger.info("Retrying a message from Resque", calledWithArguments: options)
    resque_message_handler = ResqueMessageHandler.new(
      original_message: options['original_message'],
      message: {
        'action'     => 'update',
        'barcodes'   => options['barcodes'],
        'protectCGD' => options['original_message']['protectCGD'],
        'email'      => options['original_message']['email']
      },
      expires_at: options[:expires_at],
      retry_count: options[:retry_count],
      settings: Application.settings
    )

    resque_message_handler.handle
  end
end
