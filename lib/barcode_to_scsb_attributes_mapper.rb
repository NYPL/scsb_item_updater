require 'httparty'
require 'json'
require File.join('.', 'lib', 'errorable')

class BarcodeToScsbAttributesMapper
  include Errorable
  SEARCH_TYPES = [:dummy, :complete]

  def initialize(options)
    @errors   = {}
    @barcodes = options[:barcodes]
    @api_url  = options[:api_url]
    @api_key  = options[:api_key]
  end

  # owningInstitutionItemId
  def barcode_to_attributes_mapping
    @results = find_all_barcodes(@barcodes)
  end

private

  def find_all_barcodes(barcodes)
    results = []
    found_barcodes = []

    SEARCH_TYPES.each do |search_type|
      initial_results = {}
      @barcodes.each {|barcode| initial_results[barcode.to_s] = {'customerCode' => nil, 'bibId' => nil, 'owningInstitutionHoldingsId' => nil, 'owningInstitutionItemId' => nil, 'barcode' => nil} }
      barcodes_to_be_found = barcodes - found_barcodes

      if !barcodes_to_be_found.empty?
        result = recursively_call(barcodes_to_be_found, {page_number: 0, search_type: search_type}, initial_results)
        results << result
        result.find_all {|barcode, attributes_hash| !attributes_hash.values.all?(&:nil?) }.each do |barcode, _attributes|
          found_barcodes << barcode
        end
      end
    end

    # Scrub out nils that have been found.
    # (e.g complete records that were not found in the 'dummy' search)
    results.each do |result_hash|
      result_hash.each do |barcode, attributes_hash|
        if found_barcodes.include?(barcode) && attributes_hash.values.all?(&:nil?)
          result_hash.delete(barcode)
        end
      end
    end

    result = results.inject({}) do |product, result_hash|
      product.merge(result_hash)
    end

    # We're done iterating. Add requested, but unfound barcodes to errors hash
    result.find_all {|barcode, attributes_hash| attributes_hash.values.all?(&:nil?) }.each do |barcode, customer_code|
      add_or_append_to_errors(barcode, "Could not found in SCSB's search API")
    end

    # Return the massaged value
    result
  end

  def recursively_call(barcodes, options = {}, result = {})
    begin
      response = HTTParty.post("#{@api_url}/searchService/search", headers: auth_headers, body: barcode_request_body(options[:search_type], barcodes.join(','), options[:page_number]))
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
        return result
      else
        recursively_call(@barcodes, {search_type: options[:search_type], page_number: options[:page_number] + 1}, result)
      end

    rescue Exception => e
      barcodes.each { |barcode| add_or_append_to_errors(barcode, "Bad response from SCSB API") }
      {}
    end
  end

  def auth_headers
    {
      Accept: 'application/json',
      api_key: @api_key,
      "Content-Type": 'application/json'
    }
  end

  def barcode_request_body(search_type, barcode, page_number = 1)
    if !SEARCH_TYPES.include?(search_type)
      throw "search_type unknown: #{search_type}"
    end
    search_bodies = {
      dummy: {
        deleted: false,
        fieldName: "Barcode",
        owningInstitutions: ["NYPL"],
        collectionGroupDesignations: ["NA"],
        catalogingStatus: "Incomplete",
        pageNumber: page_number,
        pageSize: 30,
        fieldValue: barcode.to_s
      },
      complete: {
        fieldName: "Barcode",
        owningInstitutions: ["NYPL"],
        pageNumber: page_number,
        pageSize: 30,
        fieldValue: barcode.to_s
      }
    }
    JSON.generate(search_bodies[search_type])
  end

end
