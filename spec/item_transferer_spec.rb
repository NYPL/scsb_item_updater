require 'spec_helper'

describe ItemTransferer do
  describe 'making calls' do
    it 'hits SCSB with the appropriate headers & body' do
      request_body = {
        'holdingTransfers' =>
        [
          {'source'       => {'owningInstitutionBibId' => 'aBibId', 'owningInstitutionHoldingsId' => 'aHoldingsId'},
           'destination' =>  {'owningInstitutionBibId' => 'destinationBibId', 'owningInstitutionHoldingsId' => 'aHoldingsId'}}
        ],
        "institution" => "NYPL"
      }

      expect(HTTParty).to receive(:post).with(
        "http://example.com/sharedCollection/transferHoldingsAndItems",
        headers: {
              Accept: 'application/json',
              api_key: 'fake_key',
              'Content-Type': 'application/json'
        },
        body: JSON.generate(request_body)
        ).
        at_least(:once).and_return('The Owls are not what they seem')

        item_transferer = ItemTransferer.new(
          api_key: 'fake_key',
          api_url: "http://example.com",
          barcode_to_attributes_mapping: {'1234' => {'bibId' => 'aBibId', 'owningInstitutionHoldingsId' => 'aHoldingsId'}},
          destination_bib_id: "destinationBibId"
        )

        item_transferer.transfer!
    end
  end

  describe 'errors' do
    it 'returns an empty hash before transfer! called' do
      expect(ItemTransferer.new.errors).to eq({})
    end

    it "parrots the 'error' message from SCSB's response if it exists"
  end
end
