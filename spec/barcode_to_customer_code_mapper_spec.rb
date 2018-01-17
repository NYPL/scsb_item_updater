require 'spec_helper'

describe BarcodeToCustomerCodeMapper do
  describe "barcode_to_customer_code_mapping" do

    it "can map an array of barcodes to a hash of barcodes => customer_code" do
      fake_scsb_response = double()
      allow(fake_scsb_response).to receive(:body) { JSON.generate({searchResultRows: [{barcode: '1234', customerCode: 'NA'}]}) }
      expect(HTTParty).to receive(:post).at_least(:once).and_return(fake_scsb_response)

      barcode_mapper = BarcodeToCustomerCodeMapper.new(barcodes: ['1234', '5678'])
      expect(barcode_mapper.barcode_to_customer_code_mapping).to eq({'1234' => "NA", "5678" => nil})
    end

    it "returns nil as a value if the barcode isn't in SCSB" do
      fake_scsb_response = double()
      allow(fake_scsb_response).to receive(:body) { JSON.generate({searchResultRows: [{barcode: '1234', customerCode: 'NA'}]}) }
      expect(HTTParty).to receive(:post).at_least(:once).and_return(fake_scsb_response)

      barcode_mapper = BarcodeToCustomerCodeMapper.new(barcodes: ['this-wont-be-there'])
      expect(barcode_mapper.barcode_to_customer_code_mapping).to eq({'this-wont-be-there' => nil})
    end
  end
end
