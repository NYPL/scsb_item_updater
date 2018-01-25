require 'spec_helper'

describe MessageHandler do

  describe "allowable actions" do

    it "has a whitelist of allowable actions" do
      expect(MessageHandler::VALID_ACTIONS).to eq(['sync'])
    end

  end

  it "will delete message and log an errror if the message isn't valid JSON"
  it "will log a 'young' message but not try to process it" do
    fake_message = double(:body => JSON.generate({}), message_attributes: {}, :attributes => {"SentTimestamp" => Time.now.to_i})
    message_handler = MessageHandler.new({message: fake_message, settings: {'minimum_message_age_seconds' => "300"}})
    NyplLogFormatter.any_instance.should_receive(:debug).with("Message '{}' is not old enough to process. It can be processed in 300 seconds")
    message_handler.handle
  end

  describe "handling a message with a value for 'action' that is not in the whitelist" do
    it "will log an error"
    it "will delete the message"
  end

end
