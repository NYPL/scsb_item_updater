require File.join(__dir__, '..', 'boot')
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

  # Build (and return) a hash mapping each valid barcode to result documents obtained via scsb api
  # Result resembles:
  #   {
  #     "33433003517483" => {
  #       "owningInstitutionBibId"=>".b118910711",
  #       "callNumber"=>"JFM 94-354",
  #       "chronologyAndEnum"=>"v. 1-2 spring 1979-summer 1980",
  #       "customerCode"=>"NA",
  #       "barcode"=>"33433003517483",
  #       "useRestriction"=>"In Library Use",
  #       "collectionGroupDesignation"=>"Shared",
  #       "availability"=>"Not Available",
  #       "selectedItem"=>false,
  #       "itemId"=>12144407,
  #       "owningInstitutionItemId"=>".i104645660",
  #       "owningInstitutionHoldingsId"=>"76cf109b-91cc-4f21-b199-b95f77bc9f2b"
  #     },
  #     ...
  #   }
  # Any unmatched barcodes will not be returned (but noted in @errors
  def barcode_to_attributes_mapping
    @results = find_all_barcodes(@barcodes)
  end

  private

  # Given an array of barcodes, returns a hash mapping barcodes to result
  # documents obtained via scsb api query (searching first "incomplete"
  # followed by "complete"). Failed lookups are not included in returned hash
  # (but are noted in @errors hash).
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
      add_or_append_to_errors(barcode, "could not be found in SCSB's search API")
    end

    # Return the massaged value
    result
  end

  # Given an array of barcodes, a request options hash, and an initial result
  # hash, returns a hash consisting of all barcodes mapped to results obtained
  # via scsb api query. The "options" param indicates `search_type` to control
  # whether this is a standard or incomplete ("dummy") search. Any barcode
  # lookup that fails will not be included in returned hash.
  def recursively_call(barcodes, options = {}, result = {})
    begin
      response = HTTParty.post("#{@api_url}/searchService/search", headers: auth_headers, body: barcode_request_body(options[:search_type], barcodes.join(','), options[:page_number]))
      parsed_body = JSON.parse(response.body)

      parsed_body['searchResultRows'].each do |result_row|
        process_row_to_result(result_row, result)
      end

      # parsed_body['totalPageCount']-1 because SCSB's pageSize params seems to be 0-indexed
      if options[:page_number] == parsed_body['totalPageCount']-1 || parsed_body['totalPageCount'] == 0
        return result
      else
        recursively_call(@barcodes, {search_type: options[:search_type], page_number: options[:page_number] + 1}, result)
      end

    rescue Exception => e
      barcodes.each { |barcode| add_or_append_to_errors(barcode, "received a bad response from SCSB API") }
      {}
    end
  end

  # Given "row" (an entry in a SCSB api result) and "result" (a hash built by
  # merging the result of several calls to this function) modifies "result" 
  # hash to include the relevant barcode mapped to relevant entry
  def process_row_to_result(row, result)
    # guard against the off-chance SCSB returns barcode that wasn't requested
    if @barcodes.include? row['barcode']
      result[row['barcode']] = row
    end

    # https://jira.nypl.org/browse/SCC-310 describes a case where in some cases, the top-level
    # barcode & customerCode are null and we must descend into the `searchItemResultRows` Array
    if row['barcode'].nil? or row['barcode'].empty?
      # additionally from SCC-1261, sometimes searchItemResultRows do not contain source bibId, 
      # so grab default value from the bib data
      default_bib_level_data = {'owningInstitutionBibId' => row['owningInstitutionBibId']} 
      row['searchItemResultRows'].each do |item_result_row|
        if @barcodes.include? item_result_row['barcode']
          result[item_result_row['barcode']] = default_bib_level_data.merge(item_result_row)
        end
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
