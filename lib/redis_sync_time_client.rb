
class RedisSyncTimeClient
  KEY_EXPIRE = 60 * 60 * 24 * 7

  def initialize
    @client = Redis.new(url: "redis://#{Application.settings['redis_domain_and_port']}")
    Application.logger.debug("RedisSyncTimeClient#initialize: Connecting to Redis: #{Application.settings['redis_domain_and_port']}")
  end

  def get_sync_time (barcode)
    time = @client.get redis_sync_time_key(barcode)
    time.to_f unless time.nil?
  end

  def set_sync_time (barcode, time = Time.new.to_f * 1000)
    @client.set redis_sync_time_key(barcode), time.to_s
    @client.expire redis_sync_time_key(barcode), KEY_EXPIRE
  end

  private

  def redis_sync_time_key (barcode)
    "sync-time-#{barcode}"
  end
end
