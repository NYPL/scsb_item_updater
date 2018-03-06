require File.join(__dir__, '..', 'boot')

class ErrorMailer
  attr_reader :from_address, :cc_addresses, :mailer_domain, :mailer_username,
    :mailer_password, :sqs_message, :environment

  #  options :from_address    [String]
  #  options :cc_addresses    [String]
  #  options :mailer_domain   [String]
  #  options :mailer_username [String]
  #  options :mailer_password [String]
  #  options :error_hashes    [Array]
  #  options :sqs_message     [Hash]
  #   a JSON.parse()ed copy of the an SQS message's body
  def initialize(options = {})
    default_options = {error_hashes: [], sqs_message: {}}
    options = default_options.merge(options)
    @from_address     = options[:from_address]
    @cc_addresses     = options[:cc_addresses]
    @mailer_domain    = options[:mailer_domain]
    @mailer_username  = options[:mailer_username]
    @mailer_password  = options[:mailer_password]
    @sqs_message      = options[:sqs_message]
    @error_hashes     = options[:error_hashes]
    @environment      = options[:environment]
  end

  def send_error_email
    if !all_errors.empty?
      get_mailer(self).deliver!
    else
      # TODO: log, don't put
      puts 'everything went fine...no errors'
    end
  end

  def all_errors
    result = Hash.new {|hash, key| hash[key] = []}

    @error_hashes.each do |error_hash|
      error_hash.each do |barcode, messages|
        result[barcode] += messages
      end
    end

    result
  end

  def email_body
    template = File.read(File.join(__dir__, '..', 'templates', 'error_email.erb'))
    renderer = ERB.new(template)
    renderer.result(binding)
  end

  private

  def get_mailer(error_mailer)
    if @environment == 'production'
      Mail.new do
        from     error_mailer.from_address
        to       error_mailer.sqs_message['email']
        subject  "ReCAP: Errors with a recent action #{Time.now}"
        # the value that cc takes is an array, so we split the environment variable with comma
        cc       error_mailer.cc_addresses.split(',')
        body     error_mailer.email_body
        delivery_method :smtp, {
          address: error_mailer.mailer_domain,
          port: 587,
          user_name: error_mailer.mailer_username,
          password: error_mailer.mailer_password,
          domain: "nypl.org",
          authentication: :login,
          enable_starttls_auto: true
        }
     end
    else
      Mail.new do
        from     error_mailer.from_address
        to       error_mailer.sqs_message['email']
        # the value that cc takes is an array, so we split the environment variable with comma
        subject  "ReCAP: Errors with a recent action #{Time.now}"
        cc       error_mailer.cc_addresses.split(',')
        body     error_mailer.email_body
        delivery_method (error_mailer.environment == 'test') ? :test : :logger
     end
    end
  end

end
