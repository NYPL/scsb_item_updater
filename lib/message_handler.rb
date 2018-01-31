Dir[File.join(__dir__, '*.rb')].each {|file| require file }
require 'nypl_log_formatter'

class MessageHandler
  VALID_ACTIONS = ['sync', 'transfer']

  #  options message    [Aws::SQS::Types::Message]
  #  options sqs_client [Class: Aws::SQS::Client]
  #  options settings   [Hash]
  def initialize(options = {})
    @message    = options[:message]
    @sqs_client = options[:sqs_client]
    @logger     = NyplLogFormatter.new(STDOUT)
    @settings   = options[:settings]
    @parsed_message = {}
  end

  def handle
    if old_enough?
      @logger.info "Message body: #{@message.body} with attributes #{@message.attributes} and user_attributes of #{@message.message_attributes}"
      @parsed_message = JSON.parse(@message.body)
      if valid?
        self.send(@parsed_message['action'])
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

  def sync
    mapper = BarcodeToScsbAttributesMapper.new({barcodes: @parsed_message['barcodes'], api_url: @settings['scsb_api_url'], api_key: @settings['scsb_api_key']})
    mapping = mapper.barcode_to_attributes_mapping
    @logger.info "MAPPING of barcodes to customerCodes: #{mapping}"
    xml_fetcher = SCSBXMLFetcher.new({
      oauth_key:    @settings['nypl_oauth_key'],
      oauth_url:    @settings['nypl_oauth_url'],
      oauth_secret: @settings['nypl_oauth_secret'],
      platform_api_url: @settings['platform_api_url'],
      barcode_to_attributes_mapping: mapping
    })
    barcode_to_scsb_xml_mapping = xml_fetcher.translate_to_scsb_xml
    @logger.info "the barcode to SCSBXML matching is #{barcode_to_scsb_xml_mapping}"

    submit_collection_updater = SubmitCollectionUpdater.new(
        barcode_to_scsb_xml_mapping: barcode_to_scsb_xml_mapping,
        api_url: @settings['scsb_api_url'],
        api_key: @settings['scsb_api_key'],
        is_gcd_protected: @parsed_message['protectCGD'],
        is_dry_run: @settings['is_dry_run'],
    )

    submit_collection_updater.update_scsb_items
    send_errors_for([mapper.errors, xml_fetcher.errors,submit_collection_updater.errors])
  end

  private

  def send_errors_for(errors = [])
    mailer = ErrorMailer.new(
      error_hashes: errors,
      sqs_message: @parsed_message,
      from_address:  @settings['email_from_address'],
      mailer_domain: @settings['smtp_domain'],
      mailer_username: @settings['smtp_user_name'],
      mailer_password: @settings['smtp_password'],
      environment: @settings['environment']
    )
    mailer.send_error_email
  end
end
