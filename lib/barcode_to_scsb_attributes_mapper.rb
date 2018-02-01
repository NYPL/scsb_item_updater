require 'httparty'
require 'json'
require File.join('.', 'lib', 'errorable')

class BarcodeToScsbAttributesMapper
  include Errorable

  def initialize(options)
    @errors   = {}
    @barcodes = options[:barcodes]
    @api_url  = options[:api_url]
    @api_key  = options[:api_key]
  end

  # owningInstitutionItemId
  def barcode_to_attributes_mapping
    initial_results = {}
    @barcodes.each {|barcode| initial_results[barcode.to_s] = {'customerCode' => nil, 'bibId' => nil, 'owningInstitutionHoldingsId' => nil, 'owningInstitutionItemId' => nil, 'barcode' => nil} }
    @results = find_all_barcodes(@barcodes, {page_number: 0}, initial_results)
  end

private

  def find_all_barcodes(barcodes, options = {}, result = {})
    begin
      response = HTTParty.post("#{@api_url}/searchService/search", headers: auth_headers, body: barcode_request_body(barcodes.join(','), options[:page_number]))
      parsed_body = JSON.parse(response.body)

      parsed_body['searchResultRows'].each do |result_row|
        # guard against the off-chance SCSB returns barcode that wasn't requested
        if @barcodes.include? result_row['barcode']
          # result[result_row['barcode']] = {'customerCode' => result_row['customerCode']}
          result[result_row['barcode']] = result_row
        end
      end

      # parsed_body['totalPageCount']-1 because SCSB's pageSize params seems to be 0-indexed
      if options[:page_number] == parsed_body['totalPageCount']-1 || parsed_body['totalPageCount'] == 0
        # We're done iterating. Add requested, but unfound barcodes to errors hash
        result.find_all {|barcode, attributes_hash| attributes_hash.values.all?(&:nil?) }.each do |barcode, customer_code|
          add_or_append_to_errors(barcode, "Could not found in SCSB's search API")
        end

        return result
      else
        find_all_barcodes(@barcodes, {page_number: options[:page_number] + 1}, result)
      end

    rescue Exception => e
      barcodes.each do |barcode|
        add_or_append_to_errors(barcode, "Bad response from SCSB API")
      end
    end
  end

  def auth_headers
    {
      Accept: 'application/json',
      api_key: @api_key,
      "Content-Type": 'application/json'
    }
  end

  def barcode_request_body(barcode, page_number = 1)
    body = {
      deleted: false,
      fieldName: "Barcode",
      owningInstitutions: ["NYPL"],
      collectionGroupDesignations: ["NA"],
      catalogingStatus: "Incomplete",
      pageNumber: page_number,
      pageSize: 30,
      fieldValue: barcode.to_s
    }
    JSON.generate(body)
  end

end
