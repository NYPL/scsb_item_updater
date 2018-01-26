require 'httparty'
require 'json'
require 'nokogiri'

class SubmitCollectionUpdater

  # options is a hash used to instantiate a SubmitCollectionUpdater
  #  options api_key [String]
  #  options api_url [String]
  #  options is_gcd_protected [Boolean]
  #  options barcode_to_scsb_xml_mapping [Hash]
  #    This is the output of SCSBXMLFetchertranslate_to_scsb_xml
  def initialize(options = {})
    @barcode_to_scsb_xml_mapping = options[:barcode_to_scsb_xml_mapping]
    @api_url  = options[:api_url]
    @api_key = options[:api_key]
    @is_gcd_protected = options[:is_gcd_protected] || false
    @is_dry_run = options[:is_dry_run]
  end

  # TODO: build up some kind of errors collection
  def update_scsb_items
    if (@is_dry_run)
      puts "This is a dry run for development. It will not update any SCSB collection item."
    else
      puts "Updating the following #{@barcode_to_scsb_xml_mapping.keys.length} barcodes: #{@barcode_to_scsb_xml_mapping.keys.join(',')}"
      @barcode_to_scsb_xml_mapping.each do |barcode, scsb_xml|
        update_item(barcode, scsb_xml)
      end
    end
  end

private

  def headers
    {
      Accept: 'application/json',
      api_key: @api_key,
      "Content-Type": 'application/json'
    }
  end

  def update_item(barcode, scsb_xml)
    # Remove <xml version=... tag
    stripped_doc = Nokogiri::XML(scsb_xml).root.to_s
    response = HTTParty.post("#{@api_url}/sharedCollection/submitCollection", headers: headers, body: stripped_doc, query: {institution: 'nypl', isCGDProtected: @is_gcd_protected})
    puts "sent barcode #{barcode} to submitCollection. The response was #{response.body}"
  end

end
