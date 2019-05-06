require 'spec_helper'

describe RedisSyncTimeClient  do
  before :each do
    @redis_client_double = instance_double(Redis)
    allow(@redis_client_double).to receive(:get).with('sync-time-1234').and_return("1556900532788.04")
    allow(@redis_client_double).to receive(:get).with('sync-time-never-synced-barcode').and_return(nil)

    allow(Redis).to receive(:new).and_return(@redis_client_double)
  end

  describe "#get_sync_time" do
    it "will return sync time as double" do
      expect(RedisSyncTimeClient.new.get_sync_time('1234')).to eq(1556900532788.04)
    end

    it "will return nil if never synced" do
      expect(RedisSyncTimeClient.new.get_sync_time('never-synced-barcode')).to be_nil
    end
  end

  describe "#set_sync_time" do
    it "will set sync time as string" do
      expect(@redis_client_double).to receive(:set).with('sync-time-1234', '999.0')
      expect(@redis_client_double).to receive(:expire).with('sync-time-1234', 60 * 60 * 24 * 7)
      RedisSyncTimeClient.new.set_sync_time('1234', 999.0)
    end
  end
end
