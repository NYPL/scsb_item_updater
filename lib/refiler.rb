require File.join('.', 'lib', 'errorable')
require 'json'
require 'nypl_log_formatter'

class Refiler
  include Errorable

  # options is a hash used to instantiate a Refiler
  #  options barcodes [Array of strings]
  #  options nypl_platform_client [NyplPlatformClient]
  #  options is_dry_run [String]
  def initialize(options = {})
    @errors = {}
    @barcodes = options[:barcodes]
    @nypl_platform_client = options[:nypl_platform_client]
    @logger = NyplLogFormatter.new(STDOUT)
    @is_dry_run = options[:is_dry_run]
  end

  def refile!
    if (@is_dry_run)
      puts "This is a dry run for development. It will not refile any SCSB collection item."
    else
      if @barcodes.empty?
        @logger.error('No valid barcodes for refile')
        puts 'No valid barcodes for refile'
      else
        @barcodes.each do |barcode|
          begin
            response = @nypl_platform_client.refile(barcode)
            if response.code >= 400
              add_or_append_to_errors(barcode, JSON.parse(response.body)['message'])
            end
          rescue Exception => e
            add_or_append_to_errors(barcode, 'Bad response from NYPL refile API')
          end
        end
      end
    end
  end

end
