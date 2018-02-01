require 'spec_helper'

describe ItemTransferer do
  describe "errors" do
    it "returns an empty hash before transfer! called" do
      expect(ItemTransferer.new.errors).to eq({})
    end
  end
end
