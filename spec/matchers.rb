require 'rdf/isomorphic'
require 'rspec/matchers'
require 'json'
require 'jsonpath'
require 'nokogiri'

RSpec::Matchers.define :produce do |expected, info = []|
  def trace(info)
    if info.respond_to?(:read)
      info.rewind
      info.read
    elsif info.is_a?(Array)
      info.join("\n")
    else
      info.to_s
    end
  end

  match do |actual|
    actual == expected
  end

  failure_message do |actual|
    "Expected: #{expected.to_json(::JSON::LD::JSON_STATE)}\n" +
    "Actual  : #{actual.to_json(::JSON::LD::JSON_STATE)}\n" +
    "Processing results:\n#{trace(info)}"
  end

  failure_message_when_negated do |actual|
    "Did not expect Expected: #{expected.to_json(::JSON::LD::JSON_STATE)}\n" +
    "Processing results:\n#{trace(info)}"
  end
end

RSpec::Matchers.define :have_jsonpath do |path, value, trace|
  p = JsonPath.new(path)
  match do |actual|
    case value
    when FalseClass
      p.on(actual).empty?
    when TrueClass
      !p.on(actual).empty?
    when Regexp
      p.on(actual).to_s =~ value
    else
      p.on(actual) == value
    end
  end
  
  failure_message do |actual|
    msg = "expected that #{path.inspect}\nwould be: #{value.inspect}"
    msg += "\n     was: #{JsonPath.new(path).on(actual)}"
    msg += "\nsource:" + actual
    msg
  end
  
  failure_message_when_negated do |actual|
    msg = "expected that #{path.inspect}\nwould not be #{value.inspect}"
    msg += "\nsource:" + actual
    msg
  end
end

RSpec::Matchers.define :have_xpath do |path, value, trace|
  match do |actual|
    @doc = Nokogiri::HTML.parse(actual)
    return false unless @doc.is_a?(Nokogiri::XML::Document)
    return false unless @doc.root.is_a?(Nokogiri::XML::Element)
    @namespaces = @doc.namespaces.merge("xhtml" => "http://www.w3.org/1999/xhtml", "xml" => "http://www.w3.org/XML/1998/namespace")
    case value
    when FalseClass
      @doc.root.at_xpath(path, @namespaces).nil?
    when TrueClass
      !@doc.root.at_xpath(path, @namespaces).nil?
    when Array
      @doc.root.at_xpath(path, @namespaces).to_s.split(" ").include?(*value)
    when Regexp
      @doc.root.at_xpath(path, @namespaces).to_s =~ value
    else
      @doc.root.at_xpath(path, @namespaces).to_s == value
    end
  end

  failure_message do |actual|
    msg = "expected that #{path.inspect}\nwould be: #{value.inspect}"
    msg += "\n     was: #{@doc.root.at_xpath(path, @namespaces)}"
    msg += "\nsource:" + actual
    msg
  end

  failure_message_when_negated do |actual|
    msg = "expected that #{path.inspect}\nwould not be #{value.inspect}"
    msg += "\nsource:" + actual
    msg
  end
end
