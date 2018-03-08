require File.join(__dir__, '..', 'resque_message_handler')
require File.join(__dir__, '..', '..', 'boot')
require 'json'

class RetriedResqueMessage
  @queue = :retrying

  def self.perform(message)
    Application.logger.info "hey, am I late: #{message}"
  end
end
