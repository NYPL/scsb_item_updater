require 'spec_helper'

describe SCSBXMLFetcher do
  describe "translate_to_scsb_xml" do

    it "maps a hash of barcodes => customer_code to a hash of barcodes and the values are SCSBXML Strings" do
      fake_nypl_bibs_response = double()
      allow(fake_nypl_bibs_response).to receive(:body) { JSON.generate({'1234' => "NA", "5678" => nil}) }
      expect(HTTParty).to receive(:post).at_least(:once).and_return(fake_nypl_bibs_response)

      fetcher = SCSBXMLFetcher.new({barcodes: {'1234' => "NA", "5678" => nil}})
      expect(fetcher.translate_to_scsb_xml).to eq({'1234' => "<?xml version=\"1.0\" ?><bibRecords></bibRecords>", "5678" => nil})
    end

    it "returns nil as a value if the barcode or customer_code isn't valid for nypl-bibs API" do
    end
  end
end



# fetcher = SCSBXMLFetcher.new({barcodes: {"1234" => "NA", "oops" => nil}})
#  Use mocking to make sure OAuth doesn't try to connect in set_token

#  making suire OAuth::Client.new returns a 'double'
#  stub the whole method chain of .client_credentials.get_token.token

#  making suire HTTParty.get returns a 'double'
#  to return "i am xml"


# expect(fetcher.translate_to_scsb_xml).to eq({"1234" => "i am xml"})