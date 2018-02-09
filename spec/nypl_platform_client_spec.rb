require 'spec_helper'

describe NyplPlatformClient do
  describe "refile" do
    it "calls the platform API with expected params" do
      fake_oauth_client = instance_double('OAuth2::Client', 'client_credentials' => double('get_token' => double('token' => 'myToken')))
      expect(OAuth2::Client).to receive(:new).at_least(:once).and_return(fake_oauth_client)
      client = NyplPlatformClient.new(platform_api_url: "https://example.com")

      request_headers = {'Accept' => "application/json", 'Authorization' => 'Bearer myToken'}
      fake_http_response = double(body: "good job", code: 200)

      expect(HTTParty).to receive(:post).at_least(:once).with(
        "https://example.com/api/v0.1/recap/refile-requests",
        headers: request_headers,
        body: JSON.generate({itemBarcode: "a-barcode"})
      ).and_return(fake_http_response)

      client.refile('a-barcode')
    end
  end

  describe "fetch_scsbxml_for" do
    it "calls the platform API with expected params"
  end
end
