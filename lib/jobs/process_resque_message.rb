require File.join(__dir__, '..', 'resque_message_handler')
require File.join(__dir__, '..', '..', 'boot')
require 'json'

# The Resque job that does all the actual handling of the message
class ProcessResqueMessage
  @queue = :work_immediately

  # message a JSON string of the original SQS message body
  def self.perform(message)
    begin
      Application.logger.info("Processing a message from SQS", original_message: message)
      parsed_message = JSON.parse(message)

      # Remove barcodes that would be redundant to process:
      parsed_message['barcodes'] = remove_redundant_barcodes parsed_message

      if parsed_message['barcodes'].empty?
        Application.logger.debug("Skipping all barcodes in batch because each of them were written to SQS before the last sync for the same item", queued_at: parsed_message['queued_at'] )
      else
        resque_message_handler = ResqueMessageHandler.new(settings: Application.settings, message: parsed_message)
        resque_message_handler.handle
        record_last_sync_times_for_barcodes parsed_message['barcodes']
      end
    rescue Exception => e
      Application.logger.error("ProcessResqueueMessage#perform: Error encountered: #{e.message}")
      raise e
    end
  end

  # Given resque message with 'barcodes' and 'queued_at' properties, returns
  # the subset of those barcodes that remains after "redundant" barcodes are
  # removed. Redundant barcodes are those queued in SQS *before* the last time
  # this tool synced them.
  def self.remove_redundant_barcodes (message)
    barcodes = message['barcodes']
    queued_at = message['queued_at'].to_f unless message['queued_at'].nil?

    # In order to process a current very large backlock of redis events that do
    # not have the new 'queued_at' property saved, let's fall back on a
    # reasonable default value for 'queued_at'. The safest choice is to set this
    # to the maximum time it can possibly be, which is the time the 'queued_at'
    # started being saved.
    # (Mult. by 1000 to convert to ms to match unit of actual queued_at values)
    queued_at = Time.new(2019, 5, 2, 10, 30, 00, '-04:00').to_f * 1000 if queued_at.nil?

    barcodes.select do |barcode|
      last_synced = last_sync_time barcode
      # Keep if 1) not synced in recent memory, or 2) queued after the most
      # recent sync:
      keep = last_synced.nil? || queued_at > last_synced
      Application.logger.debug("Skipping #{barcode} because it was written to SQS before the last sync for the same item", queued_at: queued_at, last_synced: last_synced ) if !keep
      keep
    end
  end

  # For a given array of barcodes, records current time as "sync time"
  def self.record_last_sync_times_for_barcodes (barcodes)
    barcodes.each do |barcode|
      redis_sync_time_client.set_sync_time barcode
    end
  end

  # Return last sync time (in ms since epoch)
  def self.last_sync_time (barcode)
    self.redis_sync_time_client.get_sync_time barcode
  end

  def self.redis_sync_time_client
    @@redis_client ||= RedisSyncTimeClient.new
  end
end
