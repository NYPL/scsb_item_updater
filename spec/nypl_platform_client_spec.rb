require 'spec_helper'

describe NyplPlatformClient do
  before do
    @fake_oauth_client = instance_double('OAuth2::Client', 'client_credentials' => double('get_token' => double('token' => 'myToken')))
    @client = NyplPlatformClient.new(platform_api_url: "https://example.com")
  end

  describe "refile" do
    it "calls the platform API with expected params" do
      expect(OAuth2::Client).to receive(:new).at_least(:once).and_return(@fake_oauth_client)

      request_headers = {'Accept' => "application/json", 'Authorization' => 'Bearer myToken'}
      expect(HTTParty).to receive(:post).at_least(:once).with(
        "https://example.com/api/v0.1/recap/refile-requests",
        headers: request_headers,
        body: JSON.generate({itemBarcode: "a-barcode"})
      )

      @client.refile('a-barcode')
    end
  end

  describe "fetch_scsbxml_for" do
    it "calls the platform API with expected params" do
      expect(OAuth2::Client).to receive(:new).at_least(:once).and_return(@fake_oauth_client)

      expect(HTTParty).to receive(:get).at_least(:once).with(
        "https://example.com/api/v0.1/recap/nypl-bibs",
        query: {
          customerCode: "NA",
          barcode:      "123",
          includeFullBibTree: 'false'
        },
        headers: {'Authorization' => "Bearer myToken"}
      )

      @client.fetch_scsbxml_for('123', 'NA')
    end
  end
end
