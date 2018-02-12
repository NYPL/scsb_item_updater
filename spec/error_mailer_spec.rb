require 'spec_helper'
require 'mail'

describe ErrorMailer do
  before do
    Mail::TestMailer.deliveries.clear
    @error_report_one = {
      "1234" => ["here's an error", "and another"],
      "5678" => ["meow"]}

    @error_report_two = {
      "1234" => ["and finally"],
      "001" => ["woof"]}
  end

  describe "all_errors" do
    it "will collapse errors into one hash" do
      error_mailer = ErrorMailer.new(sqs_message: {}, error_hashes: [@error_report_one, @error_report_two])
      expect(error_mailer.all_errors).to eq({
        "1234" => ["here's an error", "and another", "and finally"],
        "5678" => ["meow"],
        "001" => ["woof"]
      })
    end
  end

  describe "send_error_email" do
    it "will send and cc the errors to the respectively assigned email addresses" do
      error_mailer = ErrorMailer.new(
        from_address: "from_address@example.com",
        cc_addresses: "cc_1@example.com,cc_2@example.com",
        sqs_message: {'barcodes' => ['111', '123']},
        error_hashes: [@error_report_one, @error_report_two],
        environment:  'test'
      )

      error_mailer.send_error_email

      email = Mail::TestMailer.deliveries.last
      expect(email.from).to eq(['from_address@example.com'])
      expect(email.cc).to eq(['cc_1@example.com','cc_2@example.com'])
    end
  end
end
