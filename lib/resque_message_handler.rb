require File.join(__dir__, '..', 'boot')

class ResqueMessageHandler

  # From SCC-293
  PARTIAL_UPDATE_ERROR_MSG = 'Rejection record - Only use restriction and cgd not updated because the item is in use'

  def initialize(options = {})
    # We want to smuggle the truly original message
    # because it may be nice to talk about the original messages barcodes
    # in an error email 30 days on.
    @original_message = options[:original_message]
    @parsed_message = options[:message]
    @settings = options[:settings]
    @logger = Application.logger
    @expires_at = options[:expires_at]
    @retry_count = options[:retry_count] || 0
  end

  def handle
    self.send(@parsed_message['action'])
  end

  # TODO: Add logging of results here.
  def transfer
    source_barcode_scsb_mapper = get_barcode_mapper
    source_barcode_to_attributes_map = source_barcode_scsb_mapper.barcode_to_attributes_mapping
    @logger.info "MAPPING of barcodes to: #{source_barcode_to_attributes_map}"
    item_transferer = ItemTransferer.new({
      api_url: @settings['scsb_api_url'],
      api_key: @settings['scsb_api_key'],
      barcode_to_attributes_mapping: source_barcode_to_attributes_map,
      destination_bib_id: @parsed_message['bibRecordNumber']
    })

    # TODO: possibly wrap this all in a is_dry_run
    item_transferer.transfer!

    # don't send barcodes to SCSBXMLFetcher that errored in transfer
    item_transferer.errors.keys.each { |barcode| source_barcode_to_attributes_map.delete(barcode) }

    xml_fetcher = get_scsb_fetcher(source_barcode_to_attributes_map)
    barcode_to_scsb_xml_mapping = xml_fetcher.translate_to_scsb_xml

    submit_collection_updater = get_submit_collection_updater(barcode_to_scsb_xml_mapping)
    submit_collection_updater.update_scsb_items

    refiler = get_refiler(map_barcodes_for_refile(barcode_to_scsb_xml_mapping, submit_collection_updater.errors))
    refiler.refile!

    send_errors_for([
      source_barcode_scsb_mapper.errors,
      item_transferer.errors,
      xml_fetcher.errors,
      submit_collection_updater.errors,
      refiler.errors
    ])
  end

  def update
    mapper = get_barcode_mapper
    mapping = mapper.barcode_to_attributes_mapping
    @logger.info "MAPPING of barcodes to: #{mapping}"
    xml_fetcher = get_scsb_fetcher(mapping)

    barcode_to_scsb_xml_mapping = xml_fetcher.translate_to_scsb_xml
    @logger.info "the barcode to SCSBXML matching is #{barcode_to_scsb_xml_mapping}"

    submit_collection_updater = get_submit_collection_updater(barcode_to_scsb_xml_mapping)
    submit_collection_updater.update_scsb_items

    refiler = get_refiler(map_barcodes_for_refile(barcode_to_scsb_xml_mapping, submit_collection_updater.errors))
    refiler.refile!

    retryable_error_barcodes = submit_collection_updater.errors.select { |barcode, errors|
      errors.include? PARTIAL_UPDATE_ERROR_MSG
    }.keys

    if !retryable_error_barcodes.empty?
      if @expires_at && @expires_at < Time.now.utc
        Application.logger.info("Now send the error email")
        # TODO: Stop retrying.
        # TODO: Send the ¯\_(ツ)_/¯ - "We Tried email!"
        return #no need to refile
      end

      Resque.enqueue_in(
        Application.settings['resque_retry_rate_seconds'].to_i,
        RetriedResqueMessage,
        {
          barcodes: retryable_error_barcodes,
          original_message: @original_message || @parsed_message,
          expires_at: @expires_at || (Time.now.utc + (86400*30)),
          retry_count: @retry_count + 1
        }
      )
    end

    if @retry_count == 0
      # TODO: The language of this message may need to change to
      # reflect that we are going to retry for 30 days.
      send_errors_for([
        mapper.errors,
        xml_fetcher.errors,
        submit_collection_updater.errors,
        refiler.errors
      ])
    end
  end

  private

  def nypl_platform_client
    NyplPlatformClient.new({
      oauth_url: @settings['nypl_oauth_url'],
      oauth_key: @settings['nypl_oauth_key'],
      oauth_secret: @settings['nypl_oauth_secret'],
      platform_api_url: @settings['platform_api_url']
    })
  end

  # If a records exits in the errors of submit_collection_updater, we don't refile it
  # This method is to get all the good records and returns an array of the records to be refiled
  def map_barcodes_for_refile(all_records, records_with_submission_errors)
    all_records.keys - records_with_submission_errors.keys
  end

  def get_refiler(barcodes_for_refile)
    Refiler.new(
      nypl_platform_client: nypl_platform_client,
      barcodes: barcodes_for_refile,
      is_dry_run: @settings['is_dry_run']
    )
  end

  def get_submit_collection_updater(barcode_to_scsb_xml_mapping)
    SubmitCollectionUpdater.new(
        barcode_to_scsb_xml_mapping: barcode_to_scsb_xml_mapping,
        api_url: @settings['scsb_api_url'],
        api_key: @settings['scsb_api_key'],
        is_gcd_protected: @parsed_message['protectCGD'],
        is_dry_run: @settings['is_dry_run']
    )
  end

  def get_scsb_fetcher(barcode_to_attribute_mapping = {})
    SCSBXMLFetcher.new({
      nypl_platform_client: nypl_platform_client,
      barcode_to_attributes_mapping: barcode_to_attribute_mapping
    })
  end

  def get_barcode_mapper
    BarcodeToScsbAttributesMapper.new({
      barcodes: @parsed_message['barcodes'],
      api_url: @settings['scsb_api_url'],
      api_key: @settings['scsb_api_key']
    })
  end

  def send_errors_for(errors = [])
    mailer = ErrorMailer.new(
      error_hashes: errors,
      sqs_message: @parsed_message,
      from_address:  @settings['email_from_address'],
      cc_addresses:  @settings['email_cc_addresses'],
      mailer_domain: @settings['smtp_domain'],
      mailer_username: @settings['smtp_user_name'],
      mailer_password: @settings['smtp_password'],
      environment: @settings['environment']
    )
    mailer.send_error_email
  end

end
