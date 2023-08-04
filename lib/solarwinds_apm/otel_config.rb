module SolarWindsAPM
  # OTelConfig module
  # For configure otel component: configurable: propagator, exporter
  #                               non-config: sampler, processor, response_propagator
  # Level of this configuration: SolarWindsOTel::Config -> OboeOption -> SolarWindsOTel::OTelConfig
  module OTelConfig
    @@config           = {}
    @@config_map       = {}
    
    @@agent_enabled    = true

    def self.disable_agent
      return unless @@agent_enabled  # only show the msg once
      
      @@agent_enabled = false
      SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] Agent disabled. No Trace exported."}
    end

    def self.validate_service_key
      return unless (ENV['SW_APM_REPORTER'] || 'ssl') == 'ssl'

      disable_agent unless ENV['SW_APM_SERVICE_KEY'] || SolarWindsAPM::Config[:service_key]
    end

    def self.resolve_sampler

      resolve_sampler_config
      @@config[:sampler] = 
        ::OpenTelemetry::SDK::Trace::Samplers.parent_based(
          root: SolarWindsAPM::OpenTelemetry::SolarWindsSampler.new(@@config[:sampler_config]),
          remote_parent_sampled: SolarWindsAPM::OpenTelemetry::SolarWindsSampler.new(@@config[:sampler_config]),
          remote_parent_not_sampled: SolarWindsAPM::OpenTelemetry::SolarWindsSampler.new(@@config[:sampler_config]))
    end

    def self.resolve_sampler_config      
      sampler_config = {}
      sampler_config["trigger_trace"] = "enabled" 
      sampler_config["trigger_trace"] = nil if ENV["SW_APM_TRIGGER_TRACING_MODE"] == 'disabled'
      @@config[:sampler_config] = sampler_config
    end

    #
    # append/add solarwinds_response_propagator into rack instrumentation
    # 
    def self.resolve_for_response_propagator
      response_propagator = SolarWindsAPM::OpenTelemetry::SolarWindsResponsePropagator::TextMapPropagator.new
      if @@config_map["OpenTelemetry::Instrumentation::Rack"]
        if @@config_map["OpenTelemetry::Instrumentation::Rack"][:response_propagators].instance_of?(Array)
          @@config_map["OpenTelemetry::Instrumentation::Rack"][:response_propagators].append(response_propagator)
        else
          @@config_map["OpenTelemetry::Instrumentation::Rack"][:response_propagators] = [response_propagator]
        end
      else
        @@config_map["OpenTelemetry::Instrumentation::Rack"] = {response_propagators: [response_propagator]}
      end
    end

    def self.[](key)
      @@config[key.to_sym]
    end

    def self.print_config
      @@config.each do |config, value|
        SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] config:     #{config} = #{value}"}
      end
      @@config_map.each do |config, value|
        SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] config_map: #{config} = #{value}"}
      end
    end

    def self.resolve_solarwinds_processor
      txn_manager = SolarWindsAPM::OpenTelemetry::TxnNameManager.new
      exporter    = SolarWindsAPM::OpenTelemetry::SolarWindsExporter.new(txn_manager: txn_manager)
      @@config[:span_processor] = SolarWindsAPM::OpenTelemetry::SolarWindsProcessor.new(exporter, txn_manager)
    end

    def self.resolve_solarwinds_propagator
      @@config[:propagators] = SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new
    end

    def self.validate_propagator(propagators)
      if propagators.nil?
        disable_agent
        return
      end

      SolarWindsAPM.logger.debug {"[#{name}/#{__method__}] propagators: #{propagators.map(&:class)}"}
      unless ([::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator, ::OpenTelemetry::Baggage::Propagation::TextMapPropagator] - propagators.map(&:class)).empty? # rubocop:disable Style/GuardClause
        SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] Missing tracecontext propagator."}
        disable_agent
      end
    end

    def self.initialize
      unless defined?(::OpenTelemetry::SDK::Configurator)
        SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] missing OpenTelemetry::SDK::Configurator; opentelemetry seems not loaded."}
        disable_agent
        return
      end

      validate_service_key

      return unless @@agent_enabled

      resolve_sampler
      
      resolve_solarwinds_propagator
      resolve_solarwinds_processor
      resolve_for_response_propagator

      print_config if SolarWindsAPM.logger.level.zero?

      ENV['OTEL_TRACES_EXPORTER'] = 'none' if ENV['OTEL_TRACES_EXPORTER'].nil?
      ::OpenTelemetry::SDK.configure do |c|
        c.use_all(@@config_map)
      end
      
      validate_propagator(::OpenTelemetry.propagation.instance_variable_get(:@propagators))

      return unless @@agent_enabled

      # append our propagators
      ::OpenTelemetry.propagation.instance_variable_get(:@propagators).append(@@config[:propagators]) 
      
      # append our processors (with our exporter)      
      ::OpenTelemetry.tracer_provider.add_span_processor(@@config[:span_processor])
      
      # configure sampler afterwards
      ::OpenTelemetry.tracer_provider.sampler = @@config[:sampler]
      nil
    end

    # 
    # Allow initialize after set new value to SolarWindsAPM::Config[:key]=value
    # 
    # Usage:
    # 
    # Default using the use_all to load all instrumentation 
    # But with specific instrumentation disabled, use {:enabled: false} in config
    # SolarWindsAPM::OTelConfig.initialize_with_config do |config|
    #   config["OpenTelemetry::Instrumentation::Rack"]  = {"a" => "b"}
    #   config["OpenTelemetry::Instrumentation::Dalli"] = {:enabled: false}
    # end
    #
    def self.initialize_with_config
      unless block_given?
        SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] Block not given while doing in-code configuration. Agent disabled."}
        return
      end

      yield @@config_map

      if @@config_map.empty?
        SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] No configuration given for in-code configuration. Agent disabled."}
        return
      end

      initialize
    end
  end
end