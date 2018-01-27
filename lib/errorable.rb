# A module used to for classes that, in their duty may generate errors that we want to
# report to users. For example, an instance of BarcodeToCustomerCodeMapper may
# fail to connect to or get an unexpected response from a server.
#
# To use it `include Errorable` and make sure the constuctor initializes `@errors = {}`
# .errors() returns a hash where the key is (usually) a barcode and the value is an
# Array of Strings
module Errorable

  def self.included(base)
    attr_reader :errors
  end

protected

  def add_or_append_to_errors(barcode, message)
    if @errors[barcode]
      @errors[barcode] << message
    else
      @errors[barcode] = [message]
    end
  end

end
