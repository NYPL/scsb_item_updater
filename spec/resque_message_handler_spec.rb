require 'spec_helper'

describe ResqueMessageHandler do
  describe "#segment_by_availability" do
    it "will segment barcode mapping by availability" do
      mapping = {
        "33433003517483" => {
          "barcode"=>"33433003517483",
          "availability"=>"Not Available"
        },
        "33433003517484" => {
          "barcode"=>"33433003517484",
          "availability"=>"Available"
        },
        "33433003517485" => {
          "barcode"=>"33433003517485",
          "availability"=>"Some Other Unrecognized Status"
        }
      }

      segmented_mapping = ResqueMessageHandler.new.send :segment_by_availability, mapping
      expect(segmented_mapping).to be_a(Hash)
      expect(segmented_mapping.keys).to contain_exactly(:unavailable, :available)
      expect(segmented_mapping[:available]).to be_a(Hash)
      expect(segmented_mapping[:available].keys.size).to eq(1)
      expect(segmented_mapping[:available].keys).to contain_exactly('33433003517484')
      expect(segmented_mapping[:unavailable]).to be_a(Hash)
      expect(segmented_mapping[:unavailable].keys.size).to eq(2)
      expect(segmented_mapping[:unavailable].keys).to contain_exactly('33433003517483', '33433003517485')

      # Assert segmented documents are correct:
      available_barcodes = segmented_mapping[:available].map { |key, item| item['barcode'] }
      unavailable_barcodes = segmented_mapping[:unavailable].map { |key, item| item['barcode'] }
      expect(available_barcodes).to contain_exactly('33433003517484')
      expect(unavailable_barcodes).to contain_exactly('33433003517483', '33433003517485')
    end
  end
  
  describe "#update" do
    let(:scsb_xml_fetcher) { instance_double(SCSBXMLFetcher) }
    let(:submit_coll_updater) { instance_double(SubmitCollectionUpdater) }
    let(:refiler ) { instance_double(Refiler) }

    before :each do
      allow(scsb_xml_fetcher).to receive(:translate_to_scsb_xml).and_return({ "1234" => 'ex em el' })
      allow(scsb_xml_fetcher).to receive(:errors).and_return({})
      allow(SCSBXMLFetcher).to receive(:new).and_return(scsb_xml_fetcher)

      allow(submit_coll_updater).to receive(:update_scsb_items).and_return(nil)
      allow(submit_coll_updater).to receive(:errors).and_return({})
      allow(SubmitCollectionUpdater).to receive(:new).and_return(submit_coll_updater)

      allow(refiler).to receive(:refile!).and_return(nil)
      allow(refiler).to receive(:errors).and_return({})
      allow(Refiler).to receive(:new).and_return(refiler)
    end

    describe 'for unavailable barcode' do
      let(:barcode_mapper) { instance_double(BarcodeToScsbAttributesMapper) }

      before :each do
        allow(barcode_mapper).to receive(:barcode_to_attributes_mapping).and_return({ "1234" => { "availability" => "Not Available" } })
        allow(barcode_mapper).to receive(:errors).and_return({})
        allow(BarcodeToScsbAttributesMapper).to receive(:new).and_return(barcode_mapper)
      end

      it "will skip barcodes that are not available" do
        settings = {}
        message = { "barcodes" => [ '1234' ], "user_email" => "user@example.com", "action" => "update" }
        handler = ResqueMessageHandler.new(message: message, settings: settings)

        # Expect neither scsb-xml to be built, nor xml sent, nor refile called!
        expect(scsb_xml_fetcher).to_not receive(:translate_to_scsb_xml)
        expect(submit_coll_updater).to_not receive(:update_scsb_items)
        expect(refiler).to_not receive(:refile!)

        handler.handle
      end
    end

    describe 'for available barcode' do
      let(:barcode_mapper) { instance_double(BarcodeToScsbAttributesMapper) }

      before :each do
        allow(barcode_mapper).to receive(:barcode_to_attributes_mapping).and_return({ "1234" => { "availability" => "Available" } })
        allow(barcode_mapper).to receive(:errors).and_return({})
        allow(BarcodeToScsbAttributesMapper).to receive(:new).and_return(barcode_mapper)
      end

      it "will update and refile barcodes that are not available" do
        settings = {}
        message = { "barcodes" => [ '1234' ], "user_email" => "user@example.com", "action" => "update" }
        handler = ResqueMessageHandler.new(message: message, settings: settings)

        # Expect scsb-xml to be built, xml sent, and refile called:
        expect(scsb_xml_fetcher).to receive(:translate_to_scsb_xml)
        expect(submit_coll_updater).to receive(:update_scsb_items)
        expect(refiler).to receive(:refile!)

        handler.handle
      end
    end
  end
end

