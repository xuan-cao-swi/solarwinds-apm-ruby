# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
$LOAD_PATH.unshift("#{Dir.pwd}/lib/")

describe 'solarwinds_apm_init_7' do
  it 'SW_APM_SERVICE_KEY_is_invalid_missing_service_name' do
    puts "\n\033[1m=== TEST RUN: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

    log_output = StringIO.new
    SolarWindsAPM.logger = Logger.new(log_output)

    ENV['SW_APM_REPORTER'] = 'ssl'
    ENV['SW_APM_SERVICE_KEY'] = ''

    require './lib/solarwinds_apm'
    assert_includes log_output.string, 'SW_APM_SERVICE_KEY not configured.'
  end
end
