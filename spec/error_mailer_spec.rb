require 'spec_helper'

describe ErrorMailer do
  describe "all_errors" do
    it "will collapse errors into one hash" do
      error_report_one = {
        "1234" => ["here's an error", "and another"],
        "5678" => ["meow"]}

      error_report_two = {
        "1234" => ["and finally"],
        "001" => ["woof"]}

      error_mailer = ErrorMailer.new(sqs_message: {}, error_hashes: [error_report_one, error_report_two])
      expect(error_mailer.all_errors).to eq({
        "1234" => ["here's an error", "and another", "and finally"],
        "5678" => ["meow"],
        "001" => ["woof"]
      })
    end
  end
end
