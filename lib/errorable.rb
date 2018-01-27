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
