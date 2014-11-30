#!/usr/bin/env rackup
$:.unshift(File.expand_path('../lib',  __FILE__))

require 'rubygems' || Gem.clear_paths
require 'bundler'
Bundler.require(:default)

require 'restclient/components'
require 'rack/cache'
require 'csvw_test'

set :environment, (ENV['RACK_ENV'] || 'production').to_sym

#use Rack::Cache,
#  :verbose     => true,
#  :metastore   => "file:" + File.expand_path("../cache/meta", __FILE__),
#  :entitystore => "file:" + File.expand_path("../cache/body", __FILE__)

disable :run, :reload

run CSVWTest::Application
