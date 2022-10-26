#!/usr/bin/env rake

# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'rubygems'
require 'fileutils'
require 'net/http'
require 'optparse'
require 'digest'
require 'open-uri'
require 'bundler/setup'
require 'rake/testtask'
# require 'solarwinds_otel_apm/test'

desc 'Run all test suites defined by travis'
task :docker_tests, :environment do
  _arg1, arg2 = ARGV
  os = arg2 || 'ubuntu'

  Dir.chdir('test/run_tests')
  exec("docker-compose down -v --remove-orphans && docker-compose run --service-ports --name ruby_sw_apm_#{os} ruby_sw_apm_#{os} /code/ruby-solarwinds/test/run_tests/ruby_setup.sh test copy")
end

task :docker_test => :docker_tests

desc 'Start docker container for testing and debugging, accepts: alpine, debian, centos as args, default: ubuntu'
task :docker, :environment do
  _arg1, arg2 = ARGV
  os = arg2 || 'ubuntu'

  Dir.chdir('test/run_tests')
  exec("docker-compose down -v --remove-orphans && docker-compose run --service-ports --name ruby_sw_otel_apm_#{os} ruby_sw_otel_apm_#{os} /code/ruby-solarwinds/test/run_tests/ruby_setup.sh bash")
end

desc 'Stop all containers that were started for testing and debugging'
task 'docker_down' do
  Dir.chdir('test/run_tests')
  exec('docker-compose down')
end

desc 'Run smoke tests'
task 'smoke' do
  exec('test/run_tests/smoke_test/smoketest.sh')
end

desc 'Fetch oboe files from STAGING'
task :fetch_oboe_file_from_staging do
  swig_version = %x{swig -version} rescue ''
  swig_valid_version = swig_version.scan(/swig version [34].\d*.\d*/i)
  if swig_valid_version.empty?
    $stderr.puts '== ERROR ================================================================='
    $stderr.puts "Could not find required swig version > 3.0.8, found #{swig_version.inspect}"
    $stderr.puts 'Please install swig "> 3.0.8" and try again.'
    $stderr.puts '=========================================================================='
    raise
  else
    $stderr.puts "+++++++++++ Using #{swig_version.strip.split("\n")[0]}"
  end

  ext_src_dir = File.expand_path('ext/oboe_metal/src')
  ext_lib_dir = File.expand_path('ext/oboe_metal/lib')

  # The c-lib version is different from the gem version
  oboe_version = File.read(File.join(ext_src_dir, 'VERSION')).strip
  puts "!!!!!! C-Lib VERSION: #{oboe_version} !!!!!!!"

  oboe_stg_dir = "https://agent-binaries.global.st-ssp.solarwinds.com/apm/c-lib/#{oboe_version}"
  puts 'Fetching c-lib from STAGING'

  # remove all oboe* files, they may hang around because of name changes
  # from oboe* to oboe_api*
  Dir.glob(File.join(ext_src_dir, 'oboe*')).each { |file| File.delete(file) }

  # inform when there is a newer oboe version
  remote_file = File.join("https://agent-binaries.global.st-ssp.solarwinds.com/apm/c-lib/latest", 'VERSION')
  local_file  = File.join(ext_src_dir, 'VERSION_latest')
  URI.open(remote_file, 'rb') do |rf|
    content = rf.read
    File.open(local_file, 'wb') { |f| f.puts content }
    unless content.strip == oboe_version
      puts "FYI: latest C-Lib VERSION: #{content.strip} !"
    end
  end

  # oboe and bson header files
  FileUtils.mkdir_p(File.join(ext_src_dir, 'bson'))
  files = %w(bson/bson.h bson/platform_hacks.h)

  if ENV['OBOE_WIP'] || ENV['OBOE_LOCAL']
    wip_src_dir = File.expand_path('../oboe/liboboe')
    FileUtils.cp(File.join(wip_src_dir, 'oboe_api.cpp'), ext_src_dir)
    FileUtils.cp(File.join(wip_src_dir, 'oboe_api.h'), ext_src_dir)
    FileUtils.cp(File.join(wip_src_dir, 'oboe_debug.h'), ext_src_dir)
    FileUtils.cp(File.join(wip_src_dir, 'oboe.h'), ext_src_dir)
    FileUtils.cp(File.join(wip_src_dir, 'swig', 'oboe.i'), ext_src_dir)
  else
    files += ['oboe.h', 'oboe_api.h', 'oboe_api.cpp', 'oboe_debug.h', 'oboe.i']
  end

  files.each do |filename|
    remote_file = File.join(oboe_stg_dir, 'include', filename)
    local_file = File.join(ext_src_dir, filename)

    puts "fetching #{remote_file}"
    puts "      to #{local_file}"
    URI.open(remote_file, 'rb') do |rf|
      content = rf.read
      File.open(local_file, 'wb') { |f| f.puts content }
    end
  end

  unless ENV['OBOE_LOCAL']
    sha_files = ['liboboe-1.0-alpine-x86_64.so.0.0.0.sha256',
                 'liboboe-1.0-x86_64.so.0.0.0.sha256']

    sha_files.each do |filename|
      remote_file = File.join(oboe_stg_dir, filename)
      local_file = File.join(ext_lib_dir, filename)

      puts "fetching #{remote_file}"
      puts "      to #{local_file}"

      URI.open(remote_file, 'rb') do |rf|
        content = rf.read
        File.open(local_file, 'wb') { |f| f.puts content }
        puts "%%% #{filename} checksum: #{content.strip} %%%"
      end
    end
  end

  api_hpp_patch = File.join(ext_src_dir, 'api_hpp.patch')
  api_cpp_patch = File.join(ext_src_dir, 'api_cpp.patch')
  if File.exist?(api_hpp_patch)
    `patch -N #{File.join(ext_src_dir, 'oboe_api.h')} #{api_hpp_patch}`
  end
  if File.exist?(api_cpp_patch)
    `patch -N #{File.join(ext_src_dir, 'oboe_api.cpp')} #{api_cpp_patch}`
  end

  FileUtils.cd(ext_src_dir) do
    system('swig -c++ -ruby -module oboe_metal -o oboe_swig_wrap.cc oboe.i')
    FileUtils.rm('oboe.i')
  end
end

task :fetch => :fetch_oboe_file_from_staging

@files = %w(oboe.h oboe_api.h oboe_api.cpp oboe.i oboe_debug.h bson/bson.h bson/platform_hacks.h)
@ext_dir = File.expand_path('ext/oboe_metal')
@ext_verify_dir = File.expand_path('ext/oboe_metal/verify')

def oboe_github_fetch
  oboe_version = File.read('ext/oboe_metal/src/VERSION').strip
  oboe_token = ENV['TRACE_BUILD_TOKEN']
  oboe_github = "https://raw.githubusercontent.com/librato/solarwinds-apm-liboboe/liboboe-#{oboe_version}/liboboe/"

  FileUtils.mkdir_p(File.join(@ext_verify_dir, 'bson'))

  # fetch files
  @files.each do |filename|
    uri = filename == 'oboe.i' ? URI("#{File.join(oboe_github, 'swig', filename)}") : URI("#{File.join(oboe_github, filename)}")
    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "token #{oboe_token}"

    local_file = File.join(@ext_verify_dir, filename)

    puts "fetching #{filename}"
    puts "      to #{local_file}"

    res = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
      http.request(req)
    end

    File.open(local_file, 'wb') { |f| f.puts res.body }
  end
end

desc "Fetch oboe files from cloud.solarwinds.com and create swig wrapper"
task :fetch_oboe_file_from_prod do 
  oboe_version = File.read('ext/oboe_metal/src/VERSION').strip
  files_solarwinds = "https://agent-binaries.cloud.solarwinds.com/apm/c-lib/#{oboe_version}"

  FileUtils.mkdir_p(File.join(@ext_dir, 'src', 'bson'))

  # fetch files
  @files.each do |filename|
    remote_file = File.join(files_solarwinds, 'include', filename)
    local_file = File.join(@ext_dir, 'src', filename)

    puts "fetching #{remote_file}"
    puts "      to #{local_file}"

    URI.open(remote_file, 'rb') do |rf|
      content = rf.read
      File.open(local_file, 'wb') { |f| f.puts content }
    end
  end

  sha_files = ['liboboe-1.0-alpine-x86_64.so.0.0.0.sha256',
               'liboboe-1.0-x86_64.so.0.0.0.sha256']

  sha_files.each do |filename|
    remote_file = File.join(files_solarwinds, filename)
    local_file = File.join(@ext_dir, 'lib', filename)

    puts "fetching #{remote_file}"
    puts "      to #{local_file}"

    URI.open(remote_file, 'rb') do |rf|
      content = rf.read
      File.open(local_file, 'wb') { |f| f.puts content }
    end
  end

  FileUtils.cd(File.join(@ext_dir, 'src')) do
    system('swig -c++ -ruby -module oboe_metal -o oboe_swig_wrap.cc oboe.i')
  end
end

desc "Verify files"
task :oboe_verify do
  oboe_github_fetch
  @files.each do |filename|
    puts "Verifying #{filename}"

    sha_1 = Digest::SHA2.file(File.join(@ext_dir, 'src', filename)).hexdigest
    sha_2 = Digest::SHA2.file(File.join(@ext_verify_dir, filename)).hexdigest

    if sha_1 != sha_2
      puts "#{filename} from github and agent-binaries.cloud.solarwinds differ"
      puts `diff #{File.join(@ext_dir, 'src', filename)} #{File.join(@ext_verify_dir, filename)}`
      exit 1
    end
  end
end

desc "Build and publish to Rubygems"
# !!! publishing requires gem >=3.0.5 !!!
# Don't run with Ruby versions < 2.7 they have gem < 3.0.5
task :build_and_publish_gem do
  gemspec_file = 'solarwinds_otel_apm.gemspec'
  gemspec = Gem::Specification.load(gemspec_file)
  gem_file = gemspec.full_name + '.gem'

  exit 1 unless system('gem', 'build', gemspec_file)

  if ENV['GEM_HOST_API_KEY']
    exit 1 unless system('gem', 'push', gem_file)
  end
end

desc "Build the gem's c extension"
task :compile do
  puts "== Building the c extension against Ruby #{RUBY_VERSION}"

  pwd      = Dir.pwd
  ext_dir  = File.expand_path('ext/oboe_metal')
  final_so = File.expand_path('lib/libsolarwinds_otel_apm.so')
  so_file  = File.expand_path('ext/oboe_metal/libsolarwinds_otel_apm.so')

  Dir.chdir ext_dir
  if ENV['OBOE_LOCAL']
    cmd = [Gem.ruby, 'extconf_local.rb']
  else
    cmd = [Gem.ruby, 'extconf.rb']
  end
  sh cmd.join(' ')
  sh '/usr/bin/env make'

  File.delete(final_so) if File.exist?(final_so)

  if File.exist?(so_file)
    FileUtils.mv(so_file, final_so)
    Dir.chdir(pwd)
    puts "== Extension built and moved to #{final_so}"
  else
    Dir.chdir(pwd)
    puts '!! Extension failed to build (see above). Have the required binary and header files been fetched?'
    puts '!! Try the tasks in this order: clean > fetch > compile'
  end
end

desc 'Clean up extension build files'
task :clean do
  pwd     = Dir.pwd
  ext_dir = File.expand_path('ext/oboe_metal')
  symlinks = [
    File.expand_path('lib/libsolarwinds_otel_apm.so'),
    File.expand_path('ext/oboe_metal/lib/liboboe.so'),
    File.expand_path('ext/oboe_metal/lib/liboboe-1.0.so.0')
  ]

  symlinks.each do |symlink|
    FileUtils.rm_f symlink
  end
  Dir.chdir ext_dir
  sh '/usr/bin/env make clean' if File.exist? 'Makefile'

  FileUtils.rm_f 'src/oboe_swig_wrap.cc'
  Dir.chdir pwd
end

desc 'Remove all built files and extensions'
task :distclean do
  pwd     = Dir.pwd
  ext_dir = File.expand_path('ext/oboe_metal')
  mkmf_log = File.expand_path('ext/oboe_metal/mkmf.log')
  symlinks = [
    File.expand_path('lib/libsolarwinds_otel_apm.so'),
    File.expand_path('ext/oboe_metal/lib/liboboe.so'),
    File.expand_path('ext/oboe_metal/lib/liboboe-1.0.so.0')
  ]

  if File.exist? mkmf_log
    symlinks.each do |symlink|
      FileUtils.rm_f symlink
    end
    Dir.chdir ext_dir
    sh '/usr/bin/env make distclean' if File.exist? 'Makefile'

    Dir.chdir pwd
  else
    puts 'Nothing to distclean. (nothing built yet?)'
  end
end

desc "Rebuild the gem's c extension without fetching the oboe files, without recreating the swig wrapper"
task :recompile => [:distclean, :compile]

desc "Build the gem's c extension ..."
task :cfc => [:clean, :fetch, :compile]

task :environment do
  ENV['SW_APM_GEM_VERBOSE'] = 'true'

  Bundler.require(:default, :development)
  SolarWindsOTelAPM::Config[:tracing_mode] = :enabled
  SolarWindsOTelAPM::Test.load_extras

  require 'delayed/tasks' if SolarWindsOTelAPM::Test.gemfile?(:delayed_job)
end

# Used when testing Resque locally
task 'resque:setup' => :environment do
  require 'resque/tasks'
end

desc "Build gem locally for testing"
task :build_gem do

  puts "\n=== building for MRI ===\n"
  FileUtils.mkdir_p('builds') if Dir['builds'].size == 0
  File.delete('Gemfile.lock') if Dir['Gemfile.lock'].size == 1
  
  puts "\n=== install required dependencies ===\n"
  system('bundle install --without development --without test')

  puts "\n=== clean & compile & build ===\n"
  Rake::Task["distclean"].execute
  Rake::Task["fetch_oboe_file_from_staging"].execute # if production, then use fetch_oboe_file_from_prod
  system('gem build solarwinds_otel_apm.gemspec')
  
  gemname = Dir['solarwinds_otel_apm*.gem'].first
  FileUtils.mv(gemname, 'builds/')

  puts "\n=== last 5 built gems ===\n"
  puts Dir['builds/solarwinds_otel_apm*.gem']  

  puts "\n=== SHA256 ===\n"
  result = `ls -dt1 builds/solarwinds_otel_apm-[^pre]*.gem | head -1`
  system("shasum -a256 #{result.strip()}")

  puts "\n=== Finished ===\n"
end

desc "Build gem and push to packagecloud. Run as bundle exec rake build_gem_push_to_packagecloud[<version>]"
task :build_gem_push_to_packagecloud, [:version] do |t, args|

  require 'package_cloud'

  abort("Require PACKAGECLOUD_TOKEN\n See here: https://packagecloud.io/docs ") if ENV["PACKAGECLOUD_TOKEN"]&.empty? || ENV["PACKAGECLOUD_TOKEN"].nil?
  abort("No version specified.") if args[:version]&.empty? || args[:version].nil?

  gems = Dir["builds/solarwinds_otel_apm-#{args[:version]}.gem"]
  gem_to_push = nil
  if gems.size == 0
    Rake::Task["build_gem"].execute 
    gem_to_push = `ls -dt1 builds/solarwinds_otel_apm-[^pre]*.gem | head -1`
  else
    gem_to_push = gems.first
  end

  puts "\n=== Gem will be pushed #{gem_to_push} ===\n"
  gem_to_push_version = gem_to_push&.match(/-\d*.\d*.\d*/).to_s.gsub("-","")
  gem_to_push_version = gem_to_push&.match(/-\d*.\d*.\d*.pre/).to_s.gsub("-","") if args[:version].include? "pre"
  
  abort("Couldn't find the required gem file.") if gem_to_push.nil? || gem_to_push_version != args[:version]
    
  cli = PackageCloud::CLI::Entry.new
  cli.push("solarwinds/solarwinds-apm-ruby", gem_to_push.strip())

  puts "\n=== Finished ===\n"

end

