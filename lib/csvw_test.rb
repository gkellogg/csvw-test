require 'logger'
require 'rdf'

module CSVWTest
  autoload :Application,          "csvw_test/application"
  autoload :Core,                 "csvw_test/core"
  autoload :VERSION,              "csvw_test/version"

  APP_DIR   = File.expand_path("..", File.dirname(__FILE__))
  CACHE_DIR = File.join(APP_DIR, 'cache')
  PUB_DIR   = File.join(APP_DIR, 'public')
  TEST_URI  = RDF::URI("http://w3c.github.io/csvw/tests/")
  HOSTNAME  = (ENV['hostname'] || 'csvw.info').freeze
end