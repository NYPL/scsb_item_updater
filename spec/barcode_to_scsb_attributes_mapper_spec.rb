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
      error_message = 'Bad response from SCSB API'
      expect(@barcode_mapper.errors['1234']).to include(error_message)
      expect(@barcode_mapper.errors['5678']).to include(error_message)
    end

    it "contains an error if searchService can't find a barcode" do
      fake_scsb_response = double()
      allow(fake_scsb_response).to receive(:body) { JSON.generate({searchResultRows: [{barcode: '1234', customerCode: 'NA'}], totalPageCount: 1}) }
      expect(HTTParty).to receive(:post).at_least(:once).and_return(fake_scsb_response)

      @barcode_mapper.barcode_to_attributes_mapping
      expect(@barcode_mapper.errors).to eq({'5678' => ["Could not found in SCSB's search API"]})
    end

  end

  describe "barcode_to_attributes_mapping" do

    it "can map an array of barcodes to a hash of barcodes => customer_code" do
      fake_scsb_response = double()
      allow(fake_scsb_response).to receive(:body) { JSON.generate({searchResultRows: [{barcode: '1234', customerCode: 'NA'}], totalPageCount: 1}) }
      expect(HTTParty).to receive(:post).at_least(:once).and_return(fake_scsb_response)

      barcode_mapper = BarcodeToScsbAttributesMapper.new(barcodes: ['1234', '5678'])
      expect(barcode_mapper.barcode_to_attributes_mapping).to eq({'1234' => "NA", "5678" => nil})
    end

    it "returns nil as a value if the barcode isn't in SCSB" do
      fake_scsb_response = double()
      allow(fake_scsb_response).to receive(:body) { JSON.generate({searchResultRows: [{barcode: '1234', customerCode: 'NA'}], totalPageCount: 1}) }
      expect(HTTParty).to receive(:post).at_least(:once).and_return(fake_scsb_response)

      barcode_mapper = BarcodeToScsbAttributesMapper.new(barcodes: ['this-wont-be-there'])
      expect(barcode_mapper.barcode_to_attributes_mapping).to eq({'this-wont-be-there' => nil})
    end
  end
end
