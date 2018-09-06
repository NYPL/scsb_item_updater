require 'spec_helper'

describe Refiler do
  before do
    @refiler = Refiler.new(
      barcodes:     ['a-barcode'],
      nypl_platform_client: NyplPlatformClient.new
    )
  end

  describe 'errors' do
    before do
      @nypl_platform_client = instance_double('NyplPlatformClient')
      @refiler = Refiler.new(
        barcodes: %w[1234 5678],
        nypl_platform_client: @nypl_platform_client
      )
    end

    it 'returns an empty hash before translate_to_scsb_xml is called' do
      expect(@refiler.errors).to eq({})
    end

    it 'contains an error if there\'s an error with the connection to NYPL\'s Refile endpoint' do
      expect(@nypl_platform_client).to receive(:refile).at_least(:once).and_raise('an exception')
      @refiler.refile!
      error_message = 'received a bad response from the Sierra refile API'
      expect(@refiler.errors['1234']).to include(error_message)
    end

    it 'parrots the \'error\' message from NYPL\'s Refile endpoint response if it exists' do
      # Mock response from NYPL Refile API
      @fake_nypl_refile_response = double(
        code: 500,
        body: JSON.generate(message: 'here is an error')
      )

      expect(@nypl_platform_client).to receive(:refile).with('1234').and_return(@fake_nypl_refile_response)
      @refiler.refile!
      error_message = 'here is an error'
      expect(@refiler.errors['1234']).to include(error_message)
    end
  end

  describe 'refile!' do
    before do
      @nypl_platform_client = instance_double('NyplPlatformClient')
      @refiler = Refiler.new(
        barcodes: [],
        nypl_platform_client: @nypl_platform_client
      )
    end

    it 'will not be executed if there is no records to be refiled' do
      @refiler.refile!
      expect(@nypl_platform_client).to_not receive(:refile)
    end
  end
end
