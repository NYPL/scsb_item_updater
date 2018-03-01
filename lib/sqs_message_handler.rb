require File.join(__dir__, '..', 'boot')
require File.join(__dir__, 'jobs', 'process_resque_message')

class SQSMessageHandler
  VALID_ACTIONS = ['update', 'transfer']

  #  options message    [Aws::SQS::Types::Message]
  #  options sqs_client [Class: Aws::SQS::Client]
  #  options settings   [Hash]
  def initialize(options = {})
    @message    = options[:message]
    @sqs_client = options[:sqs_client]
    @logger     = Application.logger
    @settings   = options[:settings]
    @parsed_message = {}
  end

  def handle
    if old_enough?
      @logger.info "Message body: #{@message.body} with attributes #{@message.attributes} and user_attributes of #{@message.message_attributes}"
      @parsed_message = JSON.parse(@message.body)
      if valid?
        Resque.enqueue(ProcessResqueMessage, @message.body)
        @sqs_client.delete_message(queue_url: @settings['sqs_queue_url'], receipt_handle: @message.receipt_handle)
      else
        @logger.error("Message '#{@message.body}' contains an unsupported action")
        @sqs_client.delete_message(queue_url: @settings['sqs_queue_url'], receipt_handle: @message.receipt_handle)
      end
    else
      can_be_processed_at = (@message.attributes['SentTimestamp'][0..9].to_i + @settings['minimum_message_age_seconds'].to_i) - Time.now.utc.to_i
      @logger.debug("Message '#{@message.body}' is not old enough to process. It can be processed in #{can_be_processed_at} seconds")
    end
  end

  def valid?
    (@parsed_message['action'] && VALID_ACTIONS.include?(@parsed_message['action']))
  end

  def old_enough?
    seconds_since_publishing = Time.now.utc.to_i - @message.attributes['SentTimestamp'][0..9].to_i
    (seconds_since_publishing >= @settings['minimum_message_age_seconds'].to_i)
  end

end
