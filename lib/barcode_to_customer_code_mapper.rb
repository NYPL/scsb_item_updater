require 'httparty'
require 'json'

class BarcodeToCustomerCodeMapper

  def initialize(options)
    @barcodes = options[:barcodes]
    @api_url  = options[:api_url]
    @api_key  = options[:api_key]
  end

  def barcode_to_customer_code_mapping
    find_all_barcodes(@barcodes, {page: 1})
  end

private

  def find_all_barcodes(barcodes, options = {}, result = {})
    response = HTTParty.post("#{@api_url}/searchService/search", headers: auth_headers, body: barcode_request_body(barcodes.join(',')))
    parsed_body = JSON.parse(response.body)
    parsed_body['searchResultRows'].each do |result_row|
      # guard against the off-chance SCSB returns barcode that wasn't requested
      if @barcodes.include? result_row['barcode']
        result[result_row['barcode']] = result_row['customerCode']
      end
    end

    if options[:page] == response['totalPageCount']
      return result
    else
      find_all_barcodes(@barcodes, {page: options[:page] + 1}, result)
    end

  end

  def auth_headers
    {
      Accept: 'application/json',
      api_key: @api_key,
      "Content-Type": 'application/json'
    }
  end

  def barcode_request_body(barcode)
    body = {
      deleted: false,
      fieldName: "Barcode",
      owningInstitutions: ["NYPL"],
      collectionGroupDesignations: ["NA"],
      catalogingStatus: "Incomplete",
      pageNumber: 0,
      pageSize: 30,
      fieldValue: barcode.to_s
    }

    JSON.generate(body)
  end
end
