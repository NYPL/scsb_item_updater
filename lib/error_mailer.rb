class ErrorMailer
  #  options error_hashes    [Array]
  #  options sqs_message     [Hash]
  #  a JSON.parse()ed copy of the an SQS message's body
  def initialize(options = {})
    default_options = {error_hashes: [], sqs_message: {}}
    options = default_options.merge(options)

    @sqs_message    = options[:sqs_message]
    @error_hashes   = options[:error_hashes]
  end

  def all_errors
    result = {}
    @error_hashes.each do |error_hash|
      error_hash.each do |barcode, messages|
        if result[barcode]
          messages.each {|message| result[barcode] << message }
        else
          result[barcode] = messages
        end
      end
    end
    result
  end

end
