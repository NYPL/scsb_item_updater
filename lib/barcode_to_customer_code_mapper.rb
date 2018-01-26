require 'httparty'
require 'json'

class BarcodeToCustomerCodeMapper

  attr_reader :errors

  def initialize(options)
    @errors   = {}
    @barcodes = options[:barcodes]
    @api_url  = options[:api_url]
    @api_key  = options[:api_key]
  end

  def barcode_to_customer_code_mapping
    initial_results = {}
    @barcodes.each {|barcode| initial_results[barcode.to_s] = nil }

    results = find_all_barcodes(@barcodes, {page_number: 0}, initial_results)

    # Add requested, but unfound barcodes to errors hash
    results.find_all {|barcode, customer_code| customer_code.nil? }.each do |barcode, customer_code|
      add_or_append_to_errors(barcode, "Could not found in SCSB's search API")
    end

    results
  end

private

  def find_all_barcodes(barcodes, options = {}, result = {})
    begin
      response = HTTParty.post("#{@api_url}/searchService/search", headers: auth_headers, body: barcode_request_body(barcodes.join(','), options[:page_number]))
      parsed_body = JSON.parse(response.body)

      parsed_body['searchResultRows'].each do |result_row|
        # guard against the off-chance SCSB returns barcode that wasn't requested
        if @barcodes.include? result_row['barcode']
          result[result_row['barcode']] = result_row['customerCode']
        end
      end

      # parsed_body['totalPageCount']-1 because SCSB's pageSize params seems to be 0-indexed
      if options[:page_number] == parsed_body['totalPageCount']-1 || parsed_body['totalPageCount'] == 0
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

  def add_or_append_to_errors(barcode, message)
    if @errors[barcode]
      @errors[barcode] << message
    else
      @errors[barcode] = [message]
    end
  end

end
