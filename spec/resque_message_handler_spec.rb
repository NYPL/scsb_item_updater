require 'spec_helper'

describe ResqueMessageHandler do
  let(:mock_error_mailer) { instance_double(ErrorMailer) }

  before :each do
    allow(ErrorMailer).to receive(:new).and_return(mock_error_mailer)
    allow(mock_error_mailer).to receive(:send_error_email)
  end

  describe "#get_barcodes_allowing_updates" do
    let(:barcode_mapping) do
      {
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
        },
        "33433003517486" => {
          "barcode"=>"33433003517486",
          "availability"=>"Not Available",
          "title"=>"Dummy Title"
        }

      }
    end

    it "will select available barcodes" do
      mapping = ResqueMessageHandler.new.send :get_barcodes_allowing_updates, barcode_mapping

      expect(mapping).to be_a(Hash)
      expect(mapping.keys).to contain_exactly('33433003517484', '33433003517486')

      available_barcodes = mapping.map { |key, item| item['barcode'] }
      expect(available_barcodes).to contain_exactly('33433003517484', '33433003517486')
    end

    it "will select unavailable barcodes" do
      mapping = ResqueMessageHandler.new.send :get_barcodes_disallowing_updates, barcode_mapping

      expect(mapping.keys.size).to eq(2)
      expect(mapping.keys).to contain_exactly('33433003517483', '33433003517485')

      unavailable_barcodes = mapping.map { |key, item| item['barcode'] }
      expect(unavailable_barcodes).to contain_exactly('33433003517483', '33433003517485')
    end
  end

  describe "#update" do
    let(:scsb_xml_fetcher) { instance_double(SCSBXMLFetcher) }
    let(:submit_coll_updater) { instance_double(SubmitCollectionUpdater) }

    before :each do
      allow(scsb_xml_fetcher).to receive(:translate_to_scsb_xml).and_return({ "1234" => 'ex em el' })
      allow(scsb_xml_fetcher).to receive(:errors).and_return({})
      allow(SCSBXMLFetcher).to receive(:new).and_return(scsb_xml_fetcher)

      allow(submit_coll_updater).to receive(:update_scsb_items).and_return(nil)
      allow(submit_coll_updater).to receive(:errors).and_return({})
      allow(SubmitCollectionUpdater).to receive(:new).and_return(submit_coll_updater)
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

        # Expect neither scsb-xml to be built, nor xml sent!
        expect(scsb_xml_fetcher).to_not receive(:translate_to_scsb_xml)
        expect(submit_coll_updater).to_not receive(:update_scsb_items)
        # Expect ErrorMailer to be initialized with an error_hashes that
        # contains the specific non-availability error we're constructing:
        expect(ErrorMailer).to receive(:new).with(hash_including(:error_hashes => array_including({"1234"=>["Item is not \"Available\" in SCSB"]})))

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

      it "will update barcodes that are not available" do
        settings = {}
        message = { "barcodes" => [ '1234' ], "user_email" => "user@example.com", "action" => "update" }
        handler = ResqueMessageHandler.new(message: message, settings: settings)

        # Expect scsb-xml to be built, xml sent:
        expect(scsb_xml_fetcher).to receive(:translate_to_scsb_xml)
        expect(submit_coll_updater).to receive(:update_scsb_items)

        # ErrorMailer is instantiated when there are no errors, but
        # error_hashes contains just empty hashes
        expect(ErrorMailer).to receive(:new).with(hash_including(:error_hashes => [{}, {}, {}, {}]))

        handler.handle
      end
    end
  end
end
