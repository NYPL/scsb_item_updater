require 'httparty'
require 'oauth2'

class NyplPlatformClient
  # options is a hash used to instantiate a NyplPlatformClient
  #  options oauth_url [String]
  #  options oauth_key [String]
  #  options oauth_secret [String]
  #  options platform_api_url [String]
  def initialize(options = {})
    @oauth_url = options[:oauth_url]
    @oauth_key = options[:oauth_key]
    @oauth_secret = options[:oauth_secret]
    @platform_api_url = options[:platform_api_url]
  end

  # Returns an HTTParty response
  def refile(barcode)
    get_token
    HTTParty.post(
      "#{@platform_api_url}/api/v0.1/recap/refile-requests",
      headers: {
        'Authorization' => "Bearer #{@oauth_token}",
        'Content-Type' => 'application/json'
      },
      body: JSON.generate(itemBarcode: barcode)
    )
  end

  # Returns an HTTParty response
  def fetch_scsbxml_for(barcode, customer_code)
    get_token
    HTTParty.get(
      "#{@platform_api_url}/api/v0.1/recap/nypl-bibs",
      query: {
        customerCode: customer_code,
        barcode: barcode,
        includeFullBibTree: 'false'
      },
      headers: { 'Authorization' => "Bearer #{@oauth_token}" }
    )
  end

  private

  def get_token
    client = OAuth2::Client.new(@oauth_key, @oauth_secret, site: @oauth_url)
    @oauth_token = client.client_credentials.get_token.token
  end
end
