# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'thread'

# Disable docs and Camelcase warns since we're implementing
# an interface here.  See OboeBase for details.
# rubocop:disable Style/Documentation, Naming/MethodName
module SolarWindsOTelAPM
  extend SolarWindsOTelAPMBase
  include Oboe_metal

  class Reporter
    class << self
      ##
      # start
      #
      # Start the SolarWindsOTelAPM Reporter
      #
      def start
        SolarWindsOTelAPM.loaded = false unless SolarWindsOTelAPM::OboeInitOptions.instance.service_key_ok?
        return unless SolarWindsOTelAPM.loaded

        begin
          options = SolarWindsOTelAPM::OboeInitOptions.instance.array_for_oboe # creates an array with the options in the right order

          SolarWindsOTelAPM.reporter = Oboe_metal::Reporter.new(*options)

          # report __Init
          SolarWindsOTelAPM::LayerInit.report_init

        rescue => e
          $stderr.puts e.message
          raise
        end
      end
      alias :restart :start

      ##
      # sendReport
      #
      # Send the report for the given event
      #
      def sendReport(evt, with_system_timestamp=true)
        SolarWindsOTelAPM.reporter.sendReport(evt, with_system_timestamp)
      end

      ##
      # sendStatus
      #
      # Send the report for the given event
      #
      def sendStatus(evt, context = nil, with_system_timestamp=true)
        SolarWindsOTelAPM.reporter.sendStatus(evt, context, with_system_timestamp)
      end

      ##
      # clear_all_traces
      #
      # Truncates the trace output file to zero
      #
      def clear_all_traces
        File.truncate(SolarWindsOTelAPM::OboeInitOptions.instance.host, 0)
      end

      ##
      # get_all_traces
      #
      # Retrieves all traces written to the trace file
      #
      def get_all_traces
        io = File.open(SolarWindsOTelAPM::OboeInitOptions.instance.host, 'r')
        contents = io.readlines(nil)
        io.close

        return contents if contents.empty?

        traces = []

        # We use Gem.loaded_spec because older versions of the bson
        # gem didn't even have a version embedded in the gem.  If the
        # gem isn't in the bundle, it should rightfully error out
        # anyways.
        #
        if Gem.loaded_specs['bson'] && Gem.loaded_specs['bson'].version.to_s < '4.0'
          s = StringIO.new(contents[0])

          until s.eof?
            traces << if ::BSON.respond_to? :read_bson_document
                        BSON.read_bson_document(s)
                      else
                        BSON::Document.from_bson(s)
                      end
          end
        else
          bbb = ::BSON::ByteBuffer.new(contents[0])
          until bbb.length == 0
            traces << Hash.from_bson(bbb)
          end
        end

        traces
      end
    end
  end

  module EventUtil
    def self.metadataString(evt)
      evt.metadataString
    end
  end

  class << self
    def set_sample_rate(rate)
      return unless SolarWindsOTelAPM.loaded

      # Update liboboe with the new SampleRate value
      SolarWindsOTelAPM::Context.setDefaultSampleRate(rate.to_i)
    end
  end
end
# rubocop:enable Style/Documentation

SolarWindsOTelAPM.loaded = true
