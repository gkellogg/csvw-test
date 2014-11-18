require 'byebug'
require 'logger'

module CSVWTest
  autoload :Application,          "csvw_test/application"
  autoload :Core,                 "csvw_test/core"
  autoload :VERSION,              "csvw_test/version"

  APP_DIR = File.expand_path("..", File.dirname(__FILE__))
  PUB_DIR = File.join(APP_DIR, 'public')
  TEST_DIR = File.join(APP_DIR, 'tests')
  HOSTNAME = (ENV['hostname'] || 'csvw.info').freeze
end