Dir[File.join(__dir__, "*.rb")].each {|file| require file }
require 'nypl_log_formatter'

class MessageHandler
  VALID_ACTIONS = ['sync']

  #  options message    [Aws::SQS::Types::Message]
  #  options sqs_client [Class: Aws::SQS::Client]
  #  options settings   [Hash]
  def initialize(options = {})
    @message    = options[:message]
    @sqs_client = options[:sqs_client]
    @logger     = NyplLogFormatter.new(STDOUT)
    @settings   = options[:settings]
  end

  def handle
    if old_enough?
      @logger.info "Message body: #{@message.body} with attributes #{@message.attributes} and user_attributes of #{@message.message_attributes}"
      parsed_message = JSON.parse(@message.body)
      if parsed_message['action'] && parsed_message['action'] == 'sync'
        mapper = BarcodeToCustomerCodeMapper.new({barcodes: parsed_message['barcodes'], api_url: @settings['scsb_api_url'], api_key: @settings['scsb_api_key']})
        mapping = mapper.barcode_to_customer_code_mapping
        @logger.info "MAPPING of barcodes to customerCodes: #{mapping}"
        xml_fetcher = SCSBXMLFetcher.new({
          oauth_key:    @settings['nypl_oauth_key'],
          oauth_url:    @settings['nypl_oauth_url'],
          oauth_secret: @settings['nypl_oauth_secret'],
          platform_api_url: @settings['platform_api_url'],
          barcode_to_customer_code_mapping: mapping
        })
        barcode_to_scsb_xml_mapping = xml_fetcher.translate_to_scsb_xml
        @logger.info "the barcode to SCSBXML matching is #{barcode_to_scsb_xml_mapping}"

        submit_collection_updater = SubmitCollectionUpdater.new(
            barcode_to_scsb_xml_mapping: barcode_to_scsb_xml_mapping,
            api_url: @settings['scsb_api_url'],
            api_key: @settings['scsb_api_key'],
            is_gcd_protected: false,
        )

        submit_collection_updater.update_scsb_items
      else
        @logger.error("Not valid action from Simple Queue Service.")
      end
    else
      can_be_processed_at = Time.now.to_i + @settings['minimum_message_age_seconds'].to_i
      can_be_processed_in = can_be_processed_at - @message.attributes['SentTimestamp']
      @logger.debug("Message '#{@message.body}' is not old enough to process. It can be processed in #{can_be_processed_in} seconds")
    end
  end

  def old_enough?
    seconds_since_publishing = Time.now.to_i - @message.attributes['SentTimestamp'].to_i
    (seconds_since_publishing >= @settings['minimum_message_age_seconds'].to_i)
  end
end
