require 'spec_helper'

describe SCSBXMLFetcher do
  describe "translate_to_scsb_xml" do

    it "maps a hash of barcodes => customer_code to a hash of barcodes and the values are SCSBXML Strings" do
      # Mock OAuth
      fake_oauth_client = double()
      fake_oauth_token = double()
      fake_get_token = double()
      

      allow(fake_get_token).to receive(:token)  {"thisisfakeoauthtoken"}
      expect(OAuth2::Client).to receive(:new).at_least(:once).and_return(fake_oauth_client)
      expect(fake_oauth_client).to receive(:client_credentials).at_least(:once).and_return(fake_oauth_token)
      expect(fake_oauth_token).to receive(:get_token).at_least(:once).and_return(fake_get_token)

      # Mock actual call to nypl-bibs
      fake_nypl_bibs_response = double()
      allow(fake_nypl_bibs_response).to receive(:body).at_least(:once) { "<?xml version=\"1.0\" ?><bibRecords></bibRecords>" }

      expect(HTTParty).to receive(:get).at_least(:once).and_return(fake_nypl_bibs_response)

      fetcher = SCSBXMLFetcher.new({barcode_to_customer_code_mapping: {'1234' => "NA", "5678" => nil}})

      expect(fetcher.translate_to_scsb_xml).to eq({'1234' => "<?xml version=\"1.0\" ?><bibRecords></bibRecords>"})
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