require 'spec_helper'

describe MessageHandler do

  describe "allowable actions" do

    it "has a whitelist of allowable actions" do
      expect(MessageHandler::VALID_ACTIONS).to eq(['sync'])
    end

  end

  it "will delete message and log an errror if the message isn't valid JSON"
  it "will log a 'young' message but not try to process it"

  describe "handling a message with a value for 'action' that is not in the whitelist" do
    it "will log an error"
    it "will delete the message"
  end

end
