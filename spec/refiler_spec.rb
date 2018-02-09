require 'spec_helper'

describe Refiler do
  before do
    @refiler = Refiler.new(
      barcodes:     ['a-barcode'],
      oauth_key:    'fake-key',
      oauth_secret: 'secret',
      platform_api_url: "https://example.com"
    )
    @fake_oauth_client = instance_double('OAuth2::Client', 'client_credentials' => double('get_token' => double('token' => 'myToken')))
  end

  describe 'errors' do
    it 'returns an empty hash before translate_to_scsb_xml is called' do
      expect(@refiler.errors).to eq({})
    end
  end

  it "calls the platform API with expected params" do
    request_headers = {'Accept' => "application/json", 'Authorization' => 'Bearer myToken'}
    fake_http_response = double(body: "good job", code: 200)

    expect(OAuth2::Client).to receive(:new).at_least(:once).and_return(@fake_oauth_client)
    expect(HTTParty).to receive(:post).at_least(:once).with(
      "https://example.com/api/v0.1/recap/refile-requests",
      headers: request_headers,
      body: JSON.generate({itemBarcode: "a-barcode"})
    ).and_return(fake_http_response)

    @refiler.refile!

  end
end
