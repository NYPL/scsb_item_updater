require File.join('.', 'lib', 'errorable')
require 'oauth2'
require 'httparty'
require 'json'

class Refiler
  include Errorable
  # options is a hash used to instantiate a Refiler
  #  options barcodes [Array of strings]
  #  options oauth_key [String]
  #  options oauth_secret [String]
  #  options platform_api_url [String]
  def initialize(options = {})
    @errors = {}
    @barcodes = options[:barcodes]
    @oauth_url = options[:oauth_url]
    @oauth_key = options[:oauth_key]
    @oauth_secret = options[:oauth_secret]
    @platform_api_url = options[:platform_api_url]
  end

  def refile!
    set_token
    @barcodes.each do |barcode|
      begin
        response = HTTParty.post(
          "#{@platform_api_url}/api/v0.1/recap/refile-requests",
          headers: {'Authorization' => "Bearer #{@oauth_token}", 'Accept'=>'application/json'},
          body: JSON.generate({itemBarcode: barcode})
        )
        if response.code >= 400
          add_or_append_to_errors(barcode, JSON.parse(response.body['message']))
        end
      rescue Exception => e
        add_or_append_to_errors(barcode, 'Bad response from NYPL refile API')
      end
    end
  end

  private

  def set_token
    client = OAuth2::Client.new(@oauth_key, @oauth_secret, site: @oauth_url)
    @oauth_token = client.client_credentials.get_token.token
  end
end
