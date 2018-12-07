require 'spec_helper'

describe BarcodeToScsbAttributesMapper do

  describe "errors()" do

    before do
      @barcode_mapper = BarcodeToScsbAttributesMapper.new(barcodes: ['1234', '5678'])
    end

    it "returns an empty hash before barcode_to_attributes_mapping is called" do
      expect(@barcode_mapper.errors).to eq({})
    end

    it "contains an error if there's an error with the connection to searchService" do
      expect(HTTParty).to receive(:post).at_least(:once).and_return("This is nonsense")
      @barcode_mapper.barcode_to_attributes_mapping
      error_message = 'received a bad response from SCSB API'
      expect(@barcode_mapper.errors['1234']).to include(error_message)
      expect(@barcode_mapper.errors['5678']).to include(error_message)
    end

    it "contains an error if searchService can't find a barcode" do
      fake_scsb_response = double()
      allow(fake_scsb_response).to receive(:body) { JSON.generate({
        searchResultRows: [{barcode: '1234', customerCode: 'NA'}],
        totalPageCount: 1}
      )}

      expect(HTTParty).to receive(:post).at_least(:once).and_return(fake_scsb_response)

      @barcode_mapper.barcode_to_attributes_mapping
      expect(@barcode_mapper.errors).to eq({'5678' => ["could not be found in SCSB's search API"]})
    end

  end

  describe "barcode_to_attributes_mapping" do
    before do
      @very_empty_response = {'customerCode' => nil,  'owningInstitutionItemId' => nil, 'owningInstitutionHoldingsId' => nil, 'bibId' => nil, 'barcode' => nil}
      @response_body = JSON.generate({
        searchResultRows: [{
          owningInstitutionItemId: 'institution-item-id',
          owningInstitutionHoldingsId: 'holdings-id',
          bibId: 'bib-id',
          barcode: '1234',
          customerCode: 'NA'}],
        totalPageCount: 1
        })
    end

    it "can map an array of barcodes to a hash of barcodes => {scsb_attributes}" do
      fake_scsb_response = double()
      allow(fake_scsb_response).to receive(:body) { @response_body }
      expect(HTTParty).to receive(:post).at_least(:once).and_return(fake_scsb_response)

      barcode_mapper = BarcodeToScsbAttributesMapper.new(barcodes: ['1234', '5678'])
      expect(barcode_mapper.barcode_to_attributes_mapping['1234']).to eq({
        'customerCode' => "NA",
        'owningInstitutionItemId' => 'institution-item-id',
        'owningInstitutionHoldingsId' => 'holdings-id',
        'bibId' => 'bib-id',
        'barcode' => '1234'
      })
      expect(barcode_mapper.barcode_to_attributes_mapping['5678']).to eq(@very_empty_response)
    end

    it "returns nil as a value if the barcode isn't in SCSB" do
      fake_scsb_response = double()
      allow(fake_scsb_response).to receive(:body) { @response_body }
      expect(HTTParty).to receive(:post).at_least(:once).and_return(fake_scsb_response)

      barcode_mapper = BarcodeToScsbAttributesMapper.new(barcodes: ['this-wont-be-there'])
      expect(barcode_mapper.barcode_to_attributes_mapping['this-wont-be-there']).to eq(@very_empty_response)
    end

    it "handles result sets where all relevant data is in searchItemResultRows" do
      fake_scsb_response = double()
      allow(fake_scsb_response).to receive(:body) { 
        JSON.generate({
          searchResultRows: [{
            barcode: nil, 
            customerCode: nil,
            searchItemResultRows: [{
              barcode: '1234', 
              customerCode: 'NA',
              owningInstitutionHoldingsId: 'holdsings_id_1',
              owningInstitutionItemId: 'item_id_1',
              owningInstitutionBibId: 'bib_id_from_item_data',
            }]
          }],
          totalPageCount: 1
        })
      }
      expect(HTTParty).to receive(:post).at_least(:once).and_return(fake_scsb_response)

      barcode_mapper = BarcodeToScsbAttributesMapper.new(barcodes: ['1234'])
      expect(barcode_mapper.barcode_to_attributes_mapping['1234']).to eq(
        {
          'customerCode' => 'NA',
          'barcode' => '1234',
          'owningInstitutionHoldingsId' => 'holdsings_id_1',
          'owningInstitutionItemId' => 'item_id_1',
          'owningInstitutionBibId' => 'bib_id_from_item_data',
        }
      )

    end

    it "handles result sets where bib and item data are spread through result set" do
      fake_scsb_response = double()
      allow(fake_scsb_response).to receive(:body) { 
        JSON.generate({
          searchResultRows: [{
            barcode: nil, 
            customerCode: nil,
            owningInstitutionBibId: 'bib_id_from_bib_data',
            searchItemResultRows: [{
              barcode: '1234', 
              customerCode: 'NA',
              owningInstitutionHoldingsId: 'holdsings_id_1',
              owningInstitutionItemId: 'item_id_1',
            }]
          }],
          totalPageCount: 1
        })
      }
      expect(HTTParty).to receive(:post).at_least(:once).and_return(fake_scsb_response)

      barcode_mapper = BarcodeToScsbAttributesMapper.new(barcodes: ['1234'])
      expect(barcode_mapper.barcode_to_attributes_mapping['1234']).to eq(
        {
          'customerCode' => 'NA',
          'barcode' => '1234',
          'owningInstitutionHoldingsId' => 'holdsings_id_1',
          'owningInstitutionItemId' => 'item_id_1',
          'owningInstitutionBibId' => 'bib_id_from_bib_data',
        }
      )

    end

    it "takes the item-level data over the bib-level data if both are available" do
      fake_scsb_response = double()
      allow(fake_scsb_response).to receive(:body) { 
        JSON.generate({
          searchResultRows: [{
            barcode: nil, 
            customerCode: nil,
            owningInstitutionBibId: 'bib_id_from_bib_data',
            searchItemResultRows: [{
              barcode: '1234', 
              customerCode: 'NA',
              owningInstitutionHoldingsId: 'holdsings_id_1',
              owningInstitutionItemId: 'item_id_1',
              owningInstitutionBibId: 'bib_id_from_item_data',
            }]
          }],
          totalPageCount: 1
        })
      }
      expect(HTTParty).to receive(:post).at_least(:once).and_return(fake_scsb_response)

      barcode_mapper = BarcodeToScsbAttributesMapper.new(barcodes: ['1234'])
      expect(barcode_mapper.barcode_to_attributes_mapping['1234']).to eq(
        {
          'customerCode' => 'NA',
          'barcode' => '1234',
          'owningInstitutionHoldingsId' => 'holdsings_id_1',
          'owningInstitutionItemId' => 'item_id_1',
          'owningInstitutionBibId' => 'bib_id_from_item_data',
        }
      )

    end

  end
end
