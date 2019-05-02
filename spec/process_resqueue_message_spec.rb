require 'spec_helper'

describe ProcessResqueMessage do
  before :each do
    # Let's pretend we've just synced these two barcodes:
    ProcessResqueMessage.record_last_sync_times_for_barcodes ['012345', '67890']
  end

  describe "#record_last_sync_times_for_barcodes" do
    it "will record current times for an array of barcodes" do
      expect(ProcessResqueMessage.class_eval('@@sync_times')).to be_a(Object)
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
      expect(ProcessResqueMessage.last_sync_time('9999999999')).to be_nil
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
      barcodes = ProcessResqueMessage.remove_redundant_barcodes({ "barcodes" => ['012345', '999999999'], "queued_at" => old_queued_at })
      expect(barcodes).to be_a(Array)
      expect(barcodes.size).to eq(1)
      expect(barcodes[0]).to eq('999999999')
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

  describe "#truncate_sync_times" do
    before do
      ProcessResqueMessage.const_set 'MAX_SYNC_TIMES_REMEMBERED', 10
    end

    it "will not truncate @@sync_times if not necessary" do
      # We've already written two barcodes in root `before` so writing
      # this third barcode should produce a @@sync_times hash of length 3
      ProcessResqueMessage.record_last_sync_times_for_barcodes ['999999999']

      expect(ProcessResqueMessage.class_eval('@@sync_times')).to be_a(Object)
      expect(ProcessResqueMessage.class_eval('@@sync_times').keys.size).to eq(3)
    end

    it "will truncate @@sync_times when max entries exceeded" do
      # Get current size of hash after above tests:
      existing_sync_times_size = ProcessResqueMessage.class_eval('@@sync_times').keys.size

      # Write 10 new barcodes:
      num_to_write = 11 - existing_sync_times_size
      generated_barcodes = barcodes = (0..num_to_write).map { |i| i.to_s * 14 }
      ProcessResqueMessage.record_last_sync_times_for_barcodes generated_barcodes

      expect(ProcessResqueMessage.class_eval('@@sync_times')).to be_a(Object)
      # Expect truncation to have reduced hash size to 90% of max:
      expect(ProcessResqueMessage.class_eval('@@sync_times').keys.size).to eq(9)

      # Expect @@sync_times to only contain most recently written 9 barcodes:
      kept_keys = ProcessResqueMessage.class_eval('@@sync_times').keys
      expect(kept_keys).to contain_exactly("00000000000000", "11111111111111", "22222222222222", "33333333333333", "44444444444444", "55555555555555", "66666666666666", "77777777777777", "88888888888888")
    end
  end
end
