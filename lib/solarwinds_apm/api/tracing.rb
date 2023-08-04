module SolarWindsAPM
  module API
    module Tracing
      # Wait for SolarWinds to be ready to send traces.
      #
      # This may be useful in short lived background processes when it is important to capture
      # information during the whole time the process is running. Usually SolarWinds doesn't block an
      # application while it is starting up.
      #
      # === Argument:
      #
      # * +wait_milliseconds+ - (int, default 3000) the maximum time to wait in milliseconds
      #
      # === Example:
      #
      #   unless SolarWindsAPM::API.solarwinds_ready?(10_000)
      #     Logger.info "SolarWindsAPM not ready after 10 seconds, no metrics will be sent"
      #   end
      # 
      # === Returns:
      # * Boolean
      #
      def solarwinds_ready?(wait_milliseconds=3000)
        return false unless SolarWindsAPM.loaded

        SolarWindsAPM::Context.isReady(wait_milliseconds) == 1
      end
    end
  end
end