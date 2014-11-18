require 'linkeddata'
require 'sparql'

module CSVWTest
  ##
  # Core utilities used for generating and checking test cases
  module Core
    MANIFEST_FILE  = File.join(TEST_DIR, "manifest.ttl")
    MANIFEST_JSON  = File.join(TEST_DIR, "manifest.jsonld")
    MANIFEST_FRAME = File.join(TEST_DIR, "context.jsonld")
    BASE           = "fix:me/"

    # Internal representation of manifest
    class Manifest < JSON::LD::Resource
      attr_accessor :options

      def initialize(json, options = {})
        @options = options
        super
      end

      def entries
        # Map entries to resources
        attributes['entries'].map {|e| Entry.new(e, options)}
      end
    end

    class Entry < JSON::LD::Resource

      def initialize(json, options = {})
        @options = options
        super
      end

      def evaluate?
        Array(attributes['@type']).join(" ").match(/Eval/)
      end

      def syntax?
        Array(attributes['@type']).join(" ").match(/Syntax/)
      end

      def positive?
        !Array(attributes['@type']).join(" ").match(/Negative/)
      end
      
      def negative?
        !positive?
      end

      def json?
        !Array(attributes['@type']).join(" ").match(/json/i)
      end

      def sparql?
        !Array(attributes['@type']).join(" ").match(/sparql/i)
      end
      
      def inspect
        super.sub('>', "\n" +
        "  json?: #{json?.inspect}\n" +
        "  sparql?: #{sparql?.inspect}\n" +
        "  syntax?: #{syntax?.inspect}\n" +
        "  positive?: #{positive_test?.inspect}\n" +
        "  evaluate?: #{evaluate?.inspect}\n" +
        ">"
      )
      end

      def action_file; File.join(TEST_DIR, action.split('/').last); end
      def result_file; File.join(TEST_DIR, result.split('/').last); end
      def action_content; File.read(action_file); end
      def result_content; File.read(result_file); end
      def action_object; JSON.parse(action_content); end
      def result_object; JSON.parse(result_content); end

      ##
      # Performs a given unit test given the extractor URL
      #
      # @param [RDF::URI, String] extract_url The CSVW extractor web service.
      # @return [Array<String,Boolean>] extracted content and PASS/FAIL result
      def run(extract_url, options = {})
        # Build the RDF extractor URL
        # FIXME: include other processor control parameters
        extract_url = ::URI.decode(extract_url) + id

        logger.info entry.inspect
        logger.debug "extract from: #{extract_url}"

        # Retrieve the remote graph
        extracted = RDF::Util::File.open_file(extract_url)
        extracted_doc = extracted.read
        logger.debug "extracted:\n#{extracted_doc}, content-type: #{extracted.content_type.inspect}"

        result = if json?
          # Read both as JSON and compare
          extracted_object = JSON.parse(extracted_doc)
          JsonCompare.get_diff(extracted_object, result_object).empty?
        else
          # parse extracted as RDF
          reader = RDF::Reader.for(sample: extacted_doc)
          graph = RDF::Graph.new << reader.new(extracted_doc)
          logger.debug "extracted:\n#{graph.count} statements"
          if sparql?
            SPARQL::Grammer.open(result_file) do |query|
              graph.query(query)
            end
          else
            expected_graph = RDF::Graph.load(result_file)
            graph.isomorphic?(expected_graph)
          end
        end

        result = !result if negative?

        logger.info result ? "PASS" : "FAIL"
        [extracted_doc, result]
      end

    private
      def logger
        options[:logger] ||= begin
          l = Logger.new(STDOUT)  # In case we're not invoked from rack
          l.level = Logger::DEBUG
          l
        end
      end
    end

    ##
    # Return the Manifest source
    #
    # For version/suite specific manifests, the MF syntax is used,
    # instead of TestQuery; this makes EARL reporting simpler.
    #
    # @param [String] version
    # @param [String] suite
    def manifest_ttl
      @manifest_ttl ||= File.read(MANIFEST_FILE)
    end
    module_function :manifest_ttl

    ##
    # Return the Manifest source
    #
    # Generate a JSON-LD compatible with framing in MANIFEST_FRAME
    def manifest_json
      unless File.exist?(MANIFEST_JSON) && File.mtime(MANIFEST_JSON) >= File.mtime(MANIFEST_FILE)
        File.open(MANIFEST_JSON, "w") do |f|
          graph = RDF::Graph.new << RDF::Turtle::Reader.new(manifest_ttl)
          JSON::LD::API.fromRDF(graph) do |expanded|
            JSON::LD::API.frame(expanded, MANIFEST_FRAME) do |framed|
              json = framed.to_json(JSON::LD::JSON_STATE).gsub(BASE, "")
              f.write json
            end
          end
        end
        @manifest_json = nil
      end
      @manifest_json ||= File.read(MANIFEST_JSON)
    end
    module_function :manifest_json

    # Get manifest object
    def get_manifest
      @manifest ||= Manifest.new(JSON.parse(manifest_json)['@graph'], logger: settings.logger)
    end
    module_function :get_manifest

    ##
    # Return test details, including doc text, sparql, and extracted results
    #
    # @param [String] uri of test
    # @return [Entry]
    def get_entry(uri)
      get_manifest.entries.detect {|te| te.id == uri}
    end
    module_function :get_entry
  end

  ##
  # Standalone environment for core functions
  class StandAlone
    include Core
    
    def url(offset)
      "http://#{HOSTNAME}#{offset}"
    end
  end
end
