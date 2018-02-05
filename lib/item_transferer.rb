require File.join('.', 'lib', 'errorable')
require 'httparty'
require 'json'

class ItemTransferer
  include Errorable

  # TODO: document options
  def initialize(options = {})
    @api_key = options[:api_key]
    @api_url = options[:api_url]
    @barcode_to_attributes_mapping = options[:barcode_to_attributes_mapping]
    @destination_bib_id = options[:destination_bib_id]
    @errors = {}
  end

  def transfer!
    @barcode_to_attributes_mapping.each do |barcode, item_attributes|
      begin
        response = HTTParty.post(
          "#{@api_url}/sharedCollection/transferHoldingsAndItems",
          headers: request_headers,
          body:    request_body(item_attributes)
        )

        parsed_body = JSON.parse(response.body)
        if parsed_body["message"] != "Success"
          add_or_append_to_errors(barcode, parsed_body['holdingTransferResponses'][0]['message'])
        end
      rescue Exception => e
        # TODO: log...
        add_or_append_to_errors(barcode, 'error connecting to transferHoldingsAndItems')
      end
    end
  end

  private

  def request_headers
    {
      Accept: 'application/json',
      api_key: @api_key,
      'Content-Type': 'application/json'
    }
  end

  #
  def request_body(item_attributes)
    body = {
     "holdingTransfers": [
       {
         "source": {
           "owningInstitutionBibId": item_attributes['owningInstitutionBibId'],
           "owningInstitutionHoldingsId": item_attributes['owningInstitutionHoldingsId']
         },
         "destination": {
           "owningInstitutionBibId": @destination_bib_id,
           "owningInstitutionHoldingsId": item_attributes['owningInstitutionHoldingsId']
         }
       }
     ],
     "institution": "NYPL"
   }

   JSON.generate(body)
  end

end
