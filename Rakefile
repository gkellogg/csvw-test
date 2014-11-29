require 'bundler'
require 'fileutils'
$:.unshift(File.expand_path('../lib',  __FILE__))

namespace :cache do
  desc 'Clear document cache'
  task :clear do
    FileUtils.rm_rf File.expand_path("../cache", __FILE__)
  end
end