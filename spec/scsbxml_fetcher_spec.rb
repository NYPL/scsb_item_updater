require 'spec_helper'

describe SCSBXMLFetcher do
  describe 'translate_to_scsb_xml' do
    it 'maps a hash of barcodes => customer_code to a hash of barcodes and the values are SCSBXML Strings' do
      # Mock OAuth
      fake_oauth_client = instance_double('OAuth2::Client', 'client_credentials' => double('get_token' => double('token' => 'hi')))
      expect(OAuth2::Client).to receive(:new).at_least(:once).and_return(fake_oauth_client)

      # Mock actual call to nypl-bibs
      fake_nypl_bibs_response = double
      allow(fake_nypl_bibs_response).to receive(:body).at_least(:once) { '<?xml version=\"1.0\" ?><bibRecords></bibRecords>' }
      expect(HTTParty).to receive(:get).at_least(:once).and_return(fake_nypl_bibs_response)

      fetcher = SCSBXMLFetcher.new(barcode_to_customer_code_mapping: { '1234' => 'NA', '5678' => nil })

      expect(fetcher.translate_to_scsb_xml).to eq('1234' => '<?xml version=\"1.0\" ?><bibRecords></bibRecords>')
    end
  end
end
