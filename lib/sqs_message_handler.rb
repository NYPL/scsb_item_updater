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
    @parsed_message = JSON.parse(@message.body)
    if old_enough? || process_immediately?
      @logger.info "Message body: #{@message.body} with attributes #{@message.attributes} and user_attributes of #{@message.message_attributes}"
      if valid?
        # Copy SQS-receive-time into message as "queued_at"
        # ApproximateFirstReceiveTimestamp is ms since epoch:
        # https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_ReceiveMessage.html
        message_to_enqueue = JSON.parse(@message.body).merge({ queued_at: @message.attributes['ApproximateFirstReceiveTimestamp']}).to_json
        Resque.enqueue(ProcessResqueMessage, message_to_enqueue)
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

  # Checks parsed message for conditions that obligate processing immediately
  # (i.e. without waiting for minimum_message_age_seconds)
  def process_immediately?
    process_immediately = @parsed_message['source'] == 'bib-item-store-update'
    @logger.debug("Message '#{@message.body}' appears to be triggered by an organic update from bib/item store; Process immediately") if process_immediately
    process_immediately
  end

  def old_enough?
    seconds_since_publishing = Time.now.utc.to_i - @message.attributes['SentTimestamp'][0..9].to_i
    (seconds_since_publishing >= @settings['minimum_message_age_seconds'].to_i)
  end

end
