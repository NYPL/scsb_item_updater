require 'spec_helper'

describe SQSMessageHandler do

  describe "messages that aren't parsable JSON"

  describe "allowable actions" do

    it "has a whitelist of allowable actions" do
      expect(SQSMessageHandler::VALID_ACTIONS).to eq(['update', 'transfer'])
    end

  end

  it "will log a 'young' message but not try to process it" do
    fake_message = double(:body => JSON.generate({}), message_attributes: {}, :attributes => {"SentTimestamp" => Time.now.to_i.to_s})
    message_handler = SQSMessageHandler.new({message: fake_message, settings: {'minimum_message_age_seconds' => "300"}})
    expect(message_handler.instance_variable_get('@logger')).to receive(:debug).with("Message '{}' is not old enough to process. It can be processed in 300 seconds")
    message_handler.handle
  end

  describe "handling conditions where we should process the message" do
    before(:each) do
      @fake_sqs_client = double(:delete_message)
      @sqs_message_handler_options = {
        sqs_client: @fake_sqs_client,
        settings: {
          'sqs_queue_url' => 'http://example.com',
          'minimum_message_age_seconds' => "300"
        }
      }
    end

    it "will try to process a message if message is old enough" do
      three_hundred_seconds_ago = Time.now.to_i - 300
      fake_message = double(:body => JSON.generate({}), receipt_handle: "some-id", message_attributes: {}, :attributes => {"SentTimestamp" => three_hundred_seconds_ago.to_s})
      message_handler = SQSMessageHandler.new(@sqs_message_handler_options.merge(message: fake_message))
      expect(message_handler.instance_variable_get('@logger')).to_not receive(:debug).with("Message '{\"source\":\"bib-item-store-update\"}' is not old enough to process. It can be processed in 300 seconds")
      expect(@fake_sqs_client).to receive(:delete_message).with(queue_url: 'http://example.com', receipt_handle: "some-id")
      message_handler.handle
    end

    it "will try to process a 'young' message if message originated via organic Bib/Item service update" do
      fake_message = double(:body => JSON.generate({ source: 'bib-item-store-update' }), receipt_handle: "some-id", message_attributes: {}, :attributes => {"SentTimestamp" => Time.now.to_i.to_s})
      message_handler = SQSMessageHandler.new(@sqs_message_handler_options.merge(message: fake_message))
      expect(message_handler.instance_variable_get('@logger')).to_not receive(:debug).with("Message '{\"source\":\"bib-item-store-update\"}' is not old enough to process. It can be processed in 300 seconds")
      expect(@fake_sqs_client).to receive(:delete_message).with(queue_url: 'http://example.com', receipt_handle: "some-id")
      message_handler.handle
    end

    it "will log, without processing, a 'young' process with an unsupported source" do
      fake_message = double(:body => JSON.generate({ source: '' }), message_attributes: {}, :attributes => {"SentTimestamp" => Time.now.to_i.to_s})
      message_handler = SQSMessageHandler.new(@sqs_message_handler_options.merge(message: fake_message))
      expect(message_handler.instance_variable_get('@logger')).to receive(:debug).with("Message '{\"source\":\"\"}' is not old enough to process. It can be processed in 300 seconds")
      message_handler.handle
    end
  end

  describe "handling a message with a value for 'action' that is not in the whitelist" do

    before do
      @fake_message = double(:body => JSON.generate({action: 'iamsupported'}), receipt_handle: "some-id", message_attributes: {}, :attributes => {"SentTimestamp" => (Time.now.to_i - 86400).to_s})
    end

    it "will log an error & delete the message" do
      fake_sqs_client = double(:delete_message)
      message_handler = SQSMessageHandler.new({sqs_client: fake_sqs_client, message: @fake_message, settings: {'sqs_queue_url' => 'http://example.com', 'minimum_message_age_seconds' => "300"}})
      expect(message_handler.instance_variable_get('@logger')).to receive(:error).with("Message '{\"action\":\"iamsupported\"}' contains an unsupported action")
      expect(fake_sqs_client).to receive(:delete_message).with(queue_url: 'http://example.com', receipt_handle: "some-id")

      message_handler.handle
    end
  end
end
