require File.join(__dir__, '..', 'resque_message_handler')
require File.join(__dir__, '..', '..', 'boot')
require 'json'

# The Resque job that does all the actual handling of the message
class ProcessResqueMessage
  # Number of entries in @@sync_times hash we'll keep:
  MAX_SYNC_TIMES_REMEMBERED = 100000

  @queue = :work_immediately
  @@sync_times = {}

  # message a JSON string of the original SQS message body
  def self.perform(message)
    Application.logger.info("Processing a message from SQS", original_message: message)
    parsed_message = JSON.parse(message)
    parsed_message['barcodes'] = remove_redundant_barcodes parsed_message
    if parsed_message['barcodes'].empty?
      Application.logger.debug("Skipping all barcodes in batch because each of them were written to SQS before the last sync for the same item", queued_at: parsed_message['queued_at'] )
    else
      resque_message_handler = ResqueMessageHandler.new(settings: Application.settings, message: parsed_message)
      resque_message_handler.handle
      record_last_sync_times_for_barcodes parsed_message['barcodes']
    end
  end

  # Given resque message with 'barcodes' and 'queued_at' properties, returns
  # the subset of those barcodes that remains after "redundant" barcodes are
  # removed. Redundant barcodes are those queued in SQS *before* the last time
  # this tool synced them.
  def self.remove_redundant_barcodes (message)
    barcodes = message['barcodes']
    queued_at = message['queued_at']
    queued_at = queued_at.to_i unless queued_at.nil?
    barcodes.select do |barcode|
      last_synced = last_sync_time barcode
      keep = queued_at.nil? || last_synced.nil? || queued_at > last_synced
      Application.logger.debug("Skipping #{barcode} because it was written to SQS before the last sync for the same item", queued_at: queued_at, last_synced: last_synced ) if !keep
      keep
    end
  end

  # Return last sync time (in ms since epoc)
  def self.last_sync_time (barcode)
    @@sync_times[barcode]
  end

  # For a given array of barcodes, records current time as "sync time"
  def self.record_last_sync_times_for_barcodes (barcodes)
    current_time = Time.new.to_f * 1000
    barcodes.each do |barcode|
      @@sync_times[barcode] = current_time
    end

    truncate_sync_times
  end

  # Reduce size of @sync_times hash when necessary
  def self.truncate_sync_times
    # If size of hash is below max, noop:
    return if @@sync_times.keys.size <= MAX_SYNC_TIMES_REMEMBERED

    # Determine number to remove:
    num_to_remove = @@sync_times.keys.size - MAX_SYNC_TIMES_REMEMBERED
    # Let's remove 10% more than required to reduce how often we have to do this:
    num_to_remove += (MAX_SYNC_TIMES_REMEMBERED * 0.1).to_i

    # Map barcodes to barcode-synctime pairs:
    barcodes_to_remove = @@sync_times.keys
      .map { |k| [k, @@sync_times[k]] }
      .sort_by { |entry| entry.last } # Sort by sync time
      .slice(0, num_to_remove) # Truncate
      .map { |entry| entry.first } # Map back to barcode

    # Remove by barcode:
    barcodes_to_remove.each { |barcode| @@sync_times.delete(barcode) }

    Application.logger.debug("GC: Reduced @@sync_times map to #{@@sync_times.keys.size}")
  end
end
