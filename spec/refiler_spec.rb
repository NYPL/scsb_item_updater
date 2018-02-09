require 'spec_helper'

describe Refiler do
  before do
    @refiler = Refiler.new(
      barcodes:     ['a-barcode'],
      nypl_platform_client: NyplPlatformClient.new()
    )
  end

  describe 'errors' do
    it 'returns an empty hash before translate_to_scsb_xml is called' do
      expect(@refiler.errors).to eq({})
    end
  end

end
