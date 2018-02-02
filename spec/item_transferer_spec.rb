require 'spec_helper'

describe ItemTransferer do
  describe 'making calls' do
    it 'hits SCSB with the appropriate headers & body'
  end

  describe 'errors' do
    it 'returns an empty hash before transfer! called' do
      expect(ItemTransferer.new.errors).to eq({})
    end

    it "parrots the 'error' message from SCSB's response if it exists"
  end
end
