require 'spec_helper'

describe ProcessResqueMessage do
  before :each do
    @redis_client_double = instance_double(Redis)
    # Let's pretend we've just synced these two barcodes:
    allow(@redis_client_double).to receive(:get).with('sync-time-012345').and_return((Time.now.to_f * 1000).to_s)
    allow(@redis_client_double).to receive(:get).with('sync-time-67890').and_return((Time.now.to_f * 1000).to_s)
    allow(@redis_client_double).to receive(:get).with('sync-time-999').and_return(nil)

    allow(Redis).to receive(:new).and_return(@redis_client_double)
  end

  after :each do
    ProcessResqueMessage.class_variable_set("@@redis_client", nil)
  end

  describe "#record_last_sync_times_for_barcodes" do
    it "will record current times for an array of barcodes" do
      # expect(ProcessResqueMessage.class_eval('@@sync_times')).to be_a(Object)
    end
  end

  describe "#last_sync_time" do
    it "will return last sync time for a recently synced barcode" do
      # Expect above to record "last synced time for both barcodes to current
      # time (to within 100ms)
      current_time = Time.new.to_f * 1000
      expect(ProcessResqueMessage.last_sync_time('012345')).to be_within(100).of(current_time)
      expect(ProcessResqueMessage.last_sync_time('67890')).to be_within(100).of(current_time)
    end

    it "will return nil barcode that hasn't been synced recently" do
      expect(ProcessResqueMessage.last_sync_time('999')).to be_nil
    end
  end

  describe "#remove_redundant_barcodes" do
    it "will remove barcodes that are redundant" do
      # Let's pretend we now see a new message for one of those barcodes
      # but it was queued 10s ago:
      old_queued_at = Time.new.to_f * 1000 - 10000

      # Because the new request to sync is older than the most recent sync,
      # running it would be redundant, so we expect it will have been removed:
      barcodes = ProcessResqueMessage.remove_redundant_barcodes({ "barcodes" => ['012345'], "queued_at" => old_queued_at })
      expect(barcodes).to be_a(Array)
      expect(barcodes.size).to eq(0)
    end

    it "will retain barcodes that are not redundant" do
      # Let's pretend we now see a new message for one of those barcodes
      # but it was queued 10s ago:
      old_queued_at = Time.new.to_f * 1000 - 10000

      # Because the new request to sync is older than the most recent sync,
      # running it would be redundant, so we expect it will have been removed:
      barcodes = ProcessResqueMessage.remove_redundant_barcodes({ "barcodes" => ['012345', '999'], "queued_at" => old_queued_at })
      expect(barcodes).to be_a(Array)
      expect(barcodes.size).to eq(1)
      expect(barcodes[0]).to eq('999')
    end

    it "will remove barcodes that were not added to redis with a queued_at" do
      # Because
      #  1. the de-duping functionality depends on a new "queued_at" property
      #     having been written to the redis queue and
      #  2. we have a large back log to work through right now that does not
      #     include the queued_at property
      # .. let's set a reasonable default for the 'queued_at' property when
      # it's not found in redis queue entries. The maximum possible value for
      # queued_at is the date the "queued_at" propert was deployed (2019-5-2
      # 10:30am). This is not likely to be accurate; The real queue time is
      # necessarily earlier (a lesser time value). Because we only process
      # a given message if it appears to have been written to the queue *after*
      # the last time we synced that item, the most conservative default is the
      # maximum value possible. (i.e. this will err on the side of processing
      # an event rather than skipping it)
      #
      # Here we're attempting to process a redis message for a barcode that we
      # recently processed. Although the redis message does not include
      # queued_at property, the default queued_at will cause the barcode to be
      # removed:
      barcodes = ProcessResqueMessage.remove_redundant_barcodes({ "barcodes" => ['012345'] })
      expect(barcodes).to be_a(Array)
      expect(barcodes.size).to eq(0)
    end
  end
end
