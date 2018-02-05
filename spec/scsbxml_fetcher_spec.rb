require 'spec_helper'

describe SCSBXMLFetcher do
  describe 'errors' do
    before do
      @fetcher = SCSBXMLFetcher.new(barcode_to_attributes_mapping: { '1234' => {'customerCode' => 'NA'}, '5678' => {'customerCode' => nil} })
      # Mock OAuth
      @fake_oauth_client = instance_double('OAuth2::Client', 'client_credentials' => double('get_token' => double('token' => 'hi')))
    end

    it 'returns an empty hash before translate_to_scsb_xml is called' do
      expect(@fetcher.errors).to eq({})
    end

    it "contains an error if there's an error with the connection to NYPL Bibs" do
      expect(OAuth2::Client).to receive(:new).at_least(:once).and_return(@fake_oauth_client)
      # Mock actual call to nypl-bibs
      expect(HTTParty).to receive(:get).at_least(:once).and_raise('an exception')

      @fetcher.translate_to_scsb_xml
      error_message = 'Bad response from NYPL Bibs API'
      expect(@fetcher.errors['1234']).to include(error_message)
    end

    it 'contains an error if the barcode does not have a valid customer code' do
      expect(OAuth2::Client).to receive(:new).at_least(:once).and_return(@fake_oauth_client)
      # Mock actual call to nypl-bibs
      expect(HTTParty).to receive(:get).at_least(:once).and_raise('an exception')

      @fetcher.translate_to_scsb_xml
      error_message = 'Not have valid customer code'
      expect(@fetcher.errors['5678']).to include(error_message)
    end

    it 'contains an error if the response does not returns a valid XML' do
      expect(OAuth2::Client).to receive(:new).at_least(:once).and_return(@fake_oauth_client)
      # Mock actual call to nypl-bibs
      @fake_nypl_bibs_response = double
      allow(@fake_nypl_bibs_response).to receive(:body).at_least(:once) { '' }
      expect(HTTParty).to receive(:get).at_least(:once).and_return(@fake_nypl_bibs_response)

      @fetcher.translate_to_scsb_xml
      error_message = 'Not have valid SCSB XML'
      expect(@fetcher.errors['1234']).to include(error_message)
    end
  end

  describe 'translate_to_scsb_xml' do
    before do
      # Mock OAuth
      @fake_oauth_client = instance_double('OAuth2::Client', 'client_credentials' => double('get_token' => double('token' => 'hi')))

      # Mock actual call to nypl-bibs
      @fake_nypl_bibs_response = double
      allow(@fake_nypl_bibs_response).to receive(:body).at_least(:once) { '<?xml version=\"1.0\" ?><bibRecords></bibRecords>' }

      @fetcher = SCSBXMLFetcher.new(barcode_to_attributes_mapping: { '1234' => {'customerCode' => 'NA'}, '5678' => {'customerCode' => nil} })
    end

    it 'maps a hash of barcodes => customer_code to a hash of barcodes and the values are SCSBXML Strings' do
      expect(OAuth2::Client).to receive(:new).at_least(:once).and_return(@fake_oauth_client)
      expect(HTTParty).to receive(:get).at_least(:once).and_return(@fake_nypl_bibs_response)
      expect(@fetcher.translate_to_scsb_xml).to eq('1234' => '<?xml version=\"1.0\" ?><bibRecords></bibRecords>')
      expect(@fetcher.errors['5678']).to eq(['Not have valid customer code'])
    end
  end
end
