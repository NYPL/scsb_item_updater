class ErrorMailer
  def initialize(options = {})
    default_options = {error_hashes: []}
    options = default_options.merge(options)
    @argument = options
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
