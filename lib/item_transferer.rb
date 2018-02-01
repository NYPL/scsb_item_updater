require File.join('.', 'lib', 'errorable')

class ItemTransferer
  include Errorable

  def initialize(options = {})
    @errors = {}
  end

  def transfer!

  end
end
