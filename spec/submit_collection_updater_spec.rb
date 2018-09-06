require 'spec_helper'
require 'nokogiri'

describe SubmitCollectionUpdater do

  describe 'errors' do

    before do
      @submit_collection_updater = SubmitCollectionUpdater.new({
        barcode_to_scsb_xml_mapping: {'1234' => File.read(File.join(__dir__, 'resources', 'example_scsbxml.xml'))}
      })
    end

    it "returns an empty hash before update_scsb_itemsis called" do
      expect(@submit_collection_updater.errors).to eq({})
    end

    it "contains an error if there's an error with the connection to /sharedCollection/submitCollection" do
      expect(HTTParty).to receive(:post).at_least(:once).and_raise("an exception")
      @submit_collection_updater.update_scsb_items
      expect(@submit_collection_updater.errors).to eq({'1234' => ["received a bad response from SCSB /sharedCollection/submitCollection API"]})
    end

    it "parrots the 'error' message from SCSB's response if it exists" do
      fake_error_response = double(body: JSON.generate([{itemBarcode: "1234", message: "Invalid SCSB xml format"}]))
      expect(HTTParty).to receive(:post).at_least(:once).and_return(fake_error_response)
      @submit_collection_updater.update_scsb_items
      expect(@submit_collection_updater.errors).to eq({'1234' => ["Invalid SCSB xml format"]})
    end

    it "Won't parrot sucsess messages from SCSB's response" do
      fake_error_response = double(body: JSON.generate([{itemBarcode: "1234", message: "SuccessRecord"}]))
      expect(HTTParty).to receive(:post).at_least(:once).and_return(fake_error_response)
      @submit_collection_updater.update_scsb_items
      expect(@submit_collection_updater.errors).to eq({})
    end

  end

  describe "update_scsb_items" do

    it "calls the submitCollection with the correct parameters" do
      xml = File.read(File.join(__dir__, 'resources', 'example_scsbxml.xml'))
      request_headers = {Accept: "application/json", api_key: "fake-key", "Content-Type": 'application/json'}
      fake_http_response = double(:body => "good job")

      # This is the contract of what the API call will look like based on how
      # we instantiate the SubmitCollectionUpdater below
      expect(HTTParty).to receive(:post).with(
        "http://example.com/sharedCollection/submitCollection",
        headers: request_headers,
        body: Nokogiri::XML(xml).root.to_s,
        query: {institution: 'NYPL', isCGDProtected: false}).and_return(fake_http_response)

      updater = SubmitCollectionUpdater.new(
        barcode_to_scsb_xml_mapping: {"123" => xml},
        api_url: "http://example.com",
        api_key: 'fake-key'
      )

      updater.update_scsb_items
    end

    it 'stops submitting and throws an error if there is no valid XML' do
      xml = ''
      request_headers = {Accept: "application/json", api_key: "fake-key", "Content-Type": 'application/json'}

      updater = SubmitCollectionUpdater.new(
        barcode_to_scsb_xml_mapping: {"456" => xml},
        api_url: "http://example.com",
        api_key: 'fake-key'
      )

      updater.update_scsb_items

      error_message = 'did not not have valid SCSB XML, which will prevent record being submitted'
      expect(updater.errors['456']).to include(error_message)
    end
  end

end
