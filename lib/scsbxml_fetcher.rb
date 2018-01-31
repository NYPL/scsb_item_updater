require 'oauth2'
require 'httparty'
require 'nypl_log_formatter'
require File.join('.', 'lib', 'errorable')

class SCSBXMLFetcher
  include Errorable

  # options is a hash used to instantiate a SCSBXMLFetcher
  #  options token [String]
  #  options oauth_url [String]
  #  options oauth_key [String]
  #  options oauth_secret [String]
  #  options platform_api_url [String]
  #  options barcode_to_attributes_mapping [Hash]
  #    This is the output of BarcodeToScsbAttributesMapper#barcode_to_attributes_mapping
  def initialize(options = {})
    @token = nil
    @errors = {}
    @oauth_url = options[:oauth_url]
    @oauth_key = options[:oauth_key]
    @oauth_secret = options[:oauth_secret]
    @platform_api_url = options[:platform_api_url]
    @barcode_to_attributes_mapping = options[:barcode_to_attributes_mapping]
    @logger = NyplLogFormatter.new(STDOUT)
  end

  # returns a hash where the keys are barcodes and the values are SCSBXML Strings
  def translate_to_scsb_xml
    set_token
    results = {}
    @barcode_to_attributes_mapping.each do |barcode, scsb_attributes|
      if scsb_attributes['customerCode']
        begin
          results[barcode] = HTTParty.get(
            "#{@platform_api_url}/api/v0.1/recap/nypl-bibs",
            query: {
              customerCode: scsb_attributes['customerCode'],
              barcode: barcode,
              includeFullBibTree: 'false'
            },
            headers: { 'Authorization' => "Bearer #{@oauth_token}" }
          ).body
        rescue Exception => e
          add_or_append_to_errors(barcode, 'Bad response from NYPL Bibs API')
        end
      else
        @logger.error("Not valid customer code for the barcode: #{barcode}.")
        add_or_append_to_errors(barcode, 'Not have valid customer code')
      end
    end
    results
  end

  private

  # TODO: We should cache tokens and retry once they expire
  def set_token
    client = OAuth2::Client.new(@oauth_key, @oauth_secret, site: @oauth_url)
    @oauth_token = client.client_credentials.get_token.token
  end
end
