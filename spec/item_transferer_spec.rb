require 'spec_helper'

describe ItemTransferer do
  before do
    @request_body = {
      'holdingTransfers' =>
      [
        {'source'       => {'owningInstitutionBibId' => 'aBibId', 'owningInstitutionHoldingsId' => 'aHoldingsId'},
         'destination' =>  {'owningInstitutionBibId' => 'destinationBibId', 'owningInstitutionHoldingsId' => 'aHoldingsId'}}
      ],
      "institution" => "NYPL"
    }

    @item_transferer = ItemTransferer.new(
     api_key: 'fake_key',
     api_url: "http://example.com",
     barcode_to_attributes_mapping: {'1234' => {'owningInstitutionBibId' => 'aBibId', 'owningInstitutionHoldingsId' => 'aHoldingsId'}},
     destination_bib_id: "destinationBibId"
   )

  end

  describe 'making calls' do
    it 'hits SCSB with the appropriate headers & body' do
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
      fake_api_response = double(body: JSON.generate({message: "Failed", holdingTransferResponses: [{"message": "Source holdings is not under source bib"}]}))
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
      expect(item_transferer.errors).to eq({"1234" => ["error connecting to transferHoldingsAndItems"]})
    end
  end
end
