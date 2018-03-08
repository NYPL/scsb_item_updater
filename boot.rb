# boot.rb
#  * Requires all the gem depenedencies, reads configuration files,
#  * requires all the files used in the app
#  * Creates a basic Application class, a global that is available to anything that `require`s boot.rb
require 'json'
require 'aws-sdk'
require 'httparty'
require 'nokogiri'
require 'mail'
require 'erb'
require 'yaml'
require 'nypl_log_formatter'
require 'resque'

Dir.glob('./lib/**/*.rb').each do |file|
  require file
end

# Bring environment variables in ./config/.env into scope.
# This is only used in development.
#  * This line will no-op in production (which is good)
#  * Since ./config/.env is in .gitignore & .dockerignore we'll never put secrets into production

require 'dotenv'
Dotenv.load(File.join('.', 'config', '.env'))

# Create Application class
Application = OpenStruct.new

# Create a hash that contains the configuarable variables
path_to_settings = File.join(__dir__, "config", "settings.yml")
Application.settings = YAML.load(ERB.new(File.read(path_to_settings)).result)
Application.env = Application.settings['environment'] || 'development'

# Without this STDOUT will buffer and logs won't appear until the buffer flushes,
# In practice, that means that logs won't appear in CloudWatch until the
# container dies.
STDOUT.sync = true
Application.logger = NyplLogFormatter.new(STDOUT)

# Configure Redis
Resque.redis = Application.settings['redis_domain_and_port']
Resque.redis.namespace = "scscb_item_updater"
