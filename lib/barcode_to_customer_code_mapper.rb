require 'httparty'
require 'json'

class BarcodeToCustomerCodeMapper

  def initialize(options)
    @barcodes = options[:barcodes]
    @api_url  = options[:api_url]
    @api_key  = options[:api_key]
  end

  def barcode_to_customer_code_mapping
    result = {}

    @barcodes.each do |barcode|
      # default it to nil now, in case it's not found
      result[barcode.to_s] = nil
      response = HTTParty.post("#{@api_url}/searchService/search", headers: auth_headers, body: barcode_request_body(barcode))
      JSON.parse(response.body)['searchResultRows'].each do |result_row|
        # guard against the off-chance SCSB returns barcode that wasn't requested
        if @barcodes.include? result_row['barcode']
          result[result_row['barcode']] = result_row['customerCode']
        end
      end
    end

    result

  end

private

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
      fieldName: "",
      owningInstitutions: ["NYPL"],
      collectionGroupDesignations: ["NA"],
      catalogingStatus: "Incomplete",
      pageNumber: 0,
      pageSize: 10,
      fieldValue: barcode.to_s
    }

    JSON.generate(body)
  end
end
