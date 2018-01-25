require 'spec_helper'
require 'nokogiri'

describe SubmitCollectionUpdater do
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
        query: {institution: 'nypl', isCGDProtected: false}).and_return(fake_http_response)

      updater = SubmitCollectionUpdater.new(
        barcode_to_scsb_xml_mapping: {"123" => xml},
        api_url: "http://example.com",
        api_key: 'fake-key'
      )

      updater.update_scsb_items
    end
  end

end
