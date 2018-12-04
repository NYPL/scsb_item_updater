require File.join(__dir__, '..', 'boot')
require File.join('.', 'lib', 'errorable')
require 'securerandom'

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
          add_or_append_to_errors(barcode, parsed_body['itemTransferResponses'][0]['message'])
        end
      rescue Exception => e
        # TODO: log...
        add_or_append_to_errors(barcode, "error in making request to transferHoldingsAndItems: #{e.message}")
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
     "itemTransfers": [
       {
         "source": {
           "owningInstitutionBibId": item_attributes['owningInstitutionBibId'],
           "owningInstitutionHoldingsId": item_attributes['owningInstitutionHoldingsId'],
           "owningInstitutionItemId": item_attributes['owningInstitutionItemId']
         },
         "destination": {
           "owningInstitutionBibId": bib_with_leading_dot,
           "owningInstitutionHoldingsId": "#{bib_with_leading_dot}-#{SecureRandom.uuid}",
           "owningInstitutionItemId": item_attributes['owningInstitutionItemId']
         }
       }
     ],
     "institution": "NYPL"
   }

   JSON.generate(body)
  end

  def bib_with_leading_dot
    if @destination_bib_id && @destination_bib_id.start_with?('.')
      @destination_bib_id
    else
      ".#{@destination_bib_id}"
    end
  end

end
