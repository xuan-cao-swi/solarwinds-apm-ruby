# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'digest/sha1'

module SolarWindsOTelAPM
  module Util
    ##
    # This module was used solely for the deprecated RUM ID calculation
    # but may be useful in the future.
    #
    module Base64URL
      module_function

      def encode(bin)
        c = [bin].pack('m0').gsub(/\=+\Z/, '').tr('+/', '-_').rstrip
        m = c.size % 4
        c += '=' * (4 - m) if m != 0
        c
      end

      def decode(bin)
        m = bin.size % 4
        bin += '=' * (4 - m) if m != 0
        bin.tr('-_', '+/').unpack('m0').first
      end
    end
  end

  ##
  # This module houses all of the loading functionality for the solarwinds_apm em.

  # Note that this does not necessarily _have_ to include initialization routines
  # (although it can).
  #
  # Actual initialization is often separated out as it can be dependent on on the state
  # of the stack boot process.  e.g. code requiring that initializers, frameworks or
  # instrumented libraries are already loaded...
  #
  module Loading
    ##
    # Load the solarwinds_apm tracing API
    #
    def self.require_api
      pattern = File.join(File.dirname(__FILE__), 'api', '*.rb')
      Dir.glob(pattern) do |f|
        require f
      end

      begin
        require 'solarwinds_otel_apm/api'
      rescue LoadError => e
        SolarWindsOTelAPM.logger.fatal "[solarwinds_otel_apm/error] Couldn't load api: #{e.message}"
      end
    end
  end
end

SolarWindsOTelAPM::Loading.require_api

# Auto-start the Reporter unless we are running Unicorn on Heroku
# In that case, we start the reporters after fork
unless SolarWindsOTelAPM.heroku? && SolarWindsOTelAPM.forking_webserver?
  SolarWindsOTelAPM::Reporter.start if SolarWindsOTelAPM.loaded
end
