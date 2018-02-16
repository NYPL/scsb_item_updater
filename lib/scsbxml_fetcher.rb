require 'nypl_log_formatter'
require File.join('.', 'lib', 'errorable')

class SCSBXMLFetcher
  include Errorable

  # options is a hash used to instantiate a SCSBXMLFetcher
  #  options nypl_platform_client          [NyplPlatformClient]
  #  options barcode_to_attributes_mapping [Hash]
  #    This is the output of BarcodeToScsbAttributesMapper#barcode_to_attributes_mapping
  def initialize(options = {})
    @errors = {}
    @nypl_platform_client = options[:nypl_platform_client]
    @barcode_to_attributes_mapping = options[:barcode_to_attributes_mapping]
    @logger = NyplLogFormatter.new(STDOUT)
  end

  # returns a hash where the keys are barcodes and the values are SCSBXML Strings
  def translate_to_scsb_xml
    results = {}
    @barcode_to_attributes_mapping.each do |barcode, scsb_attributes|
      if scsb_attributes['customerCode']
        begin
          response = @nypl_platform_client.fetch_scsbxml_for(barcode, scsb_attributes['customerCode'])

          # checks response_body to see if it contains valid XML
          if response.code >= 400
            @logger.error("No valid SCSB XML from NYPL-Bibs for the barcode: #{barcode}.")
            add_or_append_to_errors(barcode, 'Not have valid SCSB XML')
          else
            results[barcode] = response.body
          end
        rescue Exception => e
          add_or_append_to_errors(barcode, 'Bad response from NYPL Bibs API')
        end
      else
        @logger.error("No valid customer code for the barcode: #{barcode}.")
        add_or_append_to_errors(barcode, 'Not have valid customer code')
      end
    end
    results
  end
end
