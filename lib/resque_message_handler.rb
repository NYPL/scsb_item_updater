require File.join(__dir__, '..', 'boot')

class ResqueMessageHandler

  def initialize(options = {})
    @parsed_message = options[:message]
    @settings = options[:settings]
    @logger = Application.logger
  end

  def handle
    self.send(@parsed_message['action'])
  end

  # TODO: Add logging of results here.
  def transfer
    @logger.info "ResqueMessageHandler#transfer: start on barcodes #{@parsed_message['barcodes']}"
    timer_start

    source_barcode_scsb_mapper = get_barcode_mapper
    timer_start (subtask = "mapper.barcode_to_attributes_mapping")
    source_barcode_to_attributes_map = source_barcode_scsb_mapper.barcode_to_attributes_mapping
    timer_stop subtask

    @logger.info "ResqueMessageHandler#transfer: MAPPING of barcodes to: #{source_barcode_to_attributes_map}"
    item_transferer = ItemTransferer.new({
      api_url: @settings['scsb_api_url'],
      api_key: @settings['scsb_api_key'],
      barcode_to_attributes_mapping: source_barcode_to_attributes_map,
      destination_bib_id: @parsed_message['bibRecordNumber']
    })

    timer_start (subtask = "item_transferer.transfer!")
    # TODO: possibly wrap this all in a is_dry_run
    item_transferer.transfer!
    timer_stop subtask

    # don't send barcodes to SCSBXMLFetcher that errored in transfer
    item_transferer.errors.keys.each { |barcode| source_barcode_to_attributes_map.delete(barcode) }

    xml_fetcher = get_scsb_fetcher(source_barcode_to_attributes_map)

    timer_start (subtask = "xml_fetcher.translate_to_scsb_xml")
    barcode_to_scsb_xml_mapping = xml_fetcher.translate_to_scsb_xml
    timer_stop subtask

    submit_collection_updater = get_submit_collection_updater(barcode_to_scsb_xml_mapping)

    timer_start (subtask = "submit_collection_updater.update_scsb_items")
    submit_collection_updater.update_scsb_items
    timer_stop subtask

    refiler = get_refiler(map_barcodes_for_refile(barcode_to_scsb_xml_mapping, submit_collection_updater.errors))
    timer_start (subtask = "refiler.refile!")
    refiler.refile!
    timer_stop subtask

    send_errors_for([
      source_barcode_scsb_mapper.errors,
      item_transferer.errors,
      xml_fetcher.errors,
      submit_collection_updater.errors,
      refiler.errors
    ])

    ellapsed_time = timer_stop
    @logger.info "ResqueMessageHandler#transfer: finished barcodes #{source_barcode_to_attributes_map.keys} in #{ellapsed_time['overall']}", action: 'transfer', ellapsed: ellapsed_time
  end

  def update
    @logger.info "ResqueMessageHandler#update: start on barcodes #{@parsed_message['barcodes']}"
    timer_start

    mapper = get_barcode_mapper

    timer_start (subtask = "mapper.barcode_to_attributes_mapping")
    mapping = mapper.barcode_to_attributes_mapping
    timer_stop subtask

    # Skip anything whose "availability" is not "Available"?
    mapping = segment_by_availability(mapping)[:available]

    # Log any item skipped due to unavailability in SCSB:
    unavailable = segment_by_availability(mapping)[:unavailable]
    @logger.debug "ResqueMessageHandler#update: Skipping updating the following unavailable barcodes: #{unavailable}" if ! unavailable.empty?

    return if mapping.empty?

    @logger.debug "ResqueMessageHandler#update: MAPPING of barcodes to: #{mapping}"
    xml_fetcher = get_scsb_fetcher(mapping)

    timer_start (subtask = "xml_fetcher.translate_to_scsb_xml")
    barcode_to_scsb_xml_mapping = xml_fetcher.translate_to_scsb_xml
    timer_stop subtask

    @logger.info "ResqueMessageHandler#update: the barcode to SCSBXML matching is #{barcode_to_scsb_xml_mapping}"

    submit_collection_updater = get_submit_collection_updater(barcode_to_scsb_xml_mapping)
    timer_start (subtask = "submit_collection_updater.update_scsb_items")
    submit_collection_updater.update_scsb_items
    timer_stop subtask

    refiler = get_refiler(map_barcodes_for_refile(barcode_to_scsb_xml_mapping, submit_collection_updater.errors))
    timer_start (subtask = "refiler.refile!")
    refiler.refile!
    timer_stop subtask

    send_errors_for([
      mapper.errors,
      xml_fetcher.errors,
      submit_collection_updater.errors,
      refiler.errors
    ])

    ellapsed_time = timer_stop
    @logger.info "ResqueMessageHandler#update: finished barcodes #{mapping.keys} in #{ellapsed_time['overall']}", action: 'update', ellapsed: ellapsed_time
  end

  private

  # Given a hash relating barcodes to scsb items, returns a new hash with two 
  # keys :available & :unavailable, each of which is a hash relating barcodes
  # to scsb documents that are Available and Not Available respectively.
  def segment_by_availability(barcode_mapping)
    barcode_mapping.inject({ available: {}, unavailable: {}}) do |h, (barcode, item)|
      group = if item['availability'] == 'Available' then :available else :unavailable end
      h[group][barcode] = item
      h
    end
  end

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

  def timer_start(task = "overall")
    @ellapsed = {} if task == "overall"
    @ellapsed[task] = Time.new
  end

  def timer_stop(task = "overall")
    @ellapsed[task] = Time.new - @ellapsed[task]
    @ellapsed
  end
end
