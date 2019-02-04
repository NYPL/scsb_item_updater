require 'spec_helper'

describe ItemTransferer do
  before do
    @request_body = {
      'itemTransfers' =>
      [
        {'source'       => {
          'owningInstitutionBibId' => 'aBibId',
          'owningInstitutionHoldingsId' => 'aHoldingsId',
          'owningInstitutionItemId' => 'anItemId'
        },
         'destination' =>  {
           'owningInstitutionBibId' => '.destinationBibId',
           'owningInstitutionHoldingsId' => '.destinationBibId-ABC-123',
           'owningInstitutionItemId' => 'anItemId'
         }
        }
      ],
      "institution" => "NYPL"
    }

    @item_transferer = ItemTransferer.new(
     api_key: 'fake_key',
     api_url: "http://example.com",
     barcode_to_attributes_mapping: {'1234' => {'owningInstitutionBibId' => 'aBibId', 'owningInstitutionHoldingsId' => 'aHoldingsId', 'owningInstitutionItemId' => 'anItemId'}},
     destination_bib_id: "destinationBibId"
   )

  end

  describe 'making calls' do
    it 'hits SCSB with the appropriate headers & body' do
      expect(SecureRandom).to receive(:uuid).at_least(:once).and_return('ABC-123')

      expect(HTTParty).to receive(:post).with(
        "http://example.com/sharedCollection/transferHoldingsAndItems",
        headers: {
              Accept: 'application/json',
              api_key: 'fake_key',
              'Content-Type': 'application/json'
        },
        body: JSON.generate(@request_body)
        ).
        at_least(:once).and_return('The Owls are not what they seem')

        @item_transferer.transfer!
    end
  end

  describe 'errors' do

    it 'returns an empty hash before transfer! called' do
      expect(ItemTransferer.new.errors).to eq({})
    end

    it "parrots the 'error' message from SCSB's response if it exists" do
      expect(SecureRandom).to receive(:uuid).at_least(:once).and_return('ABC-123')
      fake_api_response = double(body: JSON.generate({message: "Failed", itemTransferResponses: [{"message": "Source holdings is not under source bib"}]}))
      expect(HTTParty).to receive(:post).with(
        "http://example.com/sharedCollection/transferHoldingsAndItems",
        headers: {
              Accept: 'application/json',
              api_key: 'fake_key',
              'Content-Type': 'application/json'
        },
        body: JSON.generate(@request_body)
        ).
        at_least(:once).and_return(fake_api_response)

      @item_transferer.transfer!
      expect(@item_transferer.errors).to eq("1234" => ["Source holdings is not under source bib"])
    end

    it "adds an error message if there's problems connecting to SCSB's API" do
      expect(HTTParty).to receive(:post).and_raise(Exception)
      item_transferer = ItemTransferer.new(barcode_to_attributes_mapping: {"1234" => {}})
      item_transferer.transfer!
      expect(item_transferer.errors).to eq({"1234" => ["error in making request to transferHoldingsAndItems"]})
    end
  end
end
