require 'sinatra'
require 'sinatra/assetpack'
require 'digest/sha1'

module CSVWTest
  class Application < Sinatra::Base
    include Core

    configure do
      set :root, APP_DIR
      set :public_folder, PUB_DIR
      set :views, ::File.expand_path('../views',  __FILE__)
      set :app_name, "The CSVW Test Harness"
      set :raise_errors, Proc.new { !settings.production? }
      enable :logging
      disable :raise_errors, :show_exceptions if settings.environment == :production

      STDERR.puts "configure mode = #{settings.environment}"

      # Cache client requests
      RestClient.enable Rack::Cache,
        verbose:     true,
        metastore:   "file:" + ::File.join(APP_DIR, "cache/meta"),
        entitystore: "file:" + ::File.join(APP_DIR, "cache/body")

      # Load manifest
      manifest_json = JSON.parse(Core.manifest_json)
      set :manifest, Manifest.new(manifest_json)

      register Sinatra::AssetPack

      mime_type :jsonld, "application/ld+json"
      mime_type :sparql, "application/sparql-query"
      mime_type :ttl, "text/turtle"

      # Asset pipeline
      assets do
        serve '/js', from: 'assets/js'
        serve '/css', from: 'assets/css'
        #serve '/images', from: 'assets/images'

        css :app, %w(/css/application.css)
        js :app, %w(
          /js/application.js
        )

        # Skip compression
        #js_compression  :jsmin
        #css_compression :simple
      end
    end

    configure :development do
      set :logging, ::Logger.new($stdout)
      require "better_errors"
      use BetterErrors::Middleware
      BetterErrors.application_root = APP_DIR
    end

    configure :test do
      set :logging, ::Logger.new(StringIO.new)
    end

    helpers do
      # Set cache control
      def set_cache_header(options = {})
        options = {:max_age => ENV.fetch('max_age', 60*5)}.merge(options)
        cache_control(:public, :must_revalidate, options)
      end
    end

    before do
      request.logger.level = Logger::DEBUG unless settings.environment == :production
      request.logger.info "#{request.request_method} #{request.path_info} " +
        params.merge(Accept: request.accept.map(&:to_s)).map {|k,v| "#{k}=#{v}"}.join(" ")
    end

    after do
      msg = "Status: #{response.status} (#{request.request_method} #{request.path_info}), Content-Type: #{response.content_type}"
      msg += ", Location: #{response.location}" if response.location
      request.logger.info msg
    end

    # GET "/" returns test-runner page
    #
    # @method get_root
    # @overload get "/"
    get '/' do
      redirect '/tests'
    end

    get '/tests/' do
      redirect '/tests'
    end

    # GET "/tests/" returns test-manifest with representation dependent on content-negotiation. For HTML, load HTML application. Also supports `application/ld+json` and `text/turtle` formats.
    #
    # @method get_manifest
    get '/tests.?:ext?' do
      set_cache_header
      respond_to(params[:ext]) do |wants|
        wants.other {
          processors = File.read(File.join(settings.root, "processors.json"))
          content_type :html
          haml :tests, locals: {
            processors: processors,
            angular_app: "testApp",
            title: "foo",
            description: "bar"
          }          
        }
        wants.jsonld {
          etag manifest_json.hash
          content_type :jsonld
          body manifest_json
        }
        wants.ttl {
          etag manifest_ttl.to_s.hash
          content_type :ttl
          body manifest_ttl.to_s
        }
      end
    end

    # GET "/tests/:testId" returns a paritulcar test entry.
    # If no entry is found, it looks for a file in the test directory.
    #
    # TODO: if HTML is requested 
    #
    # @method get_entry
    # @param [String] testId last path component indicating particular test
    get '/tests/:testId.?:ext?' do
      if entry = settings.manifest.entry(params[:testId])
        respond_to(params[:ext]) do |wants|
          wants.jsonld {
            set_cache_header
            etag entry.hash
            content_type :jsonld
            body entry.to_json
          }
        end
      else
        # Otherwise, it might be a file
        #pass
        raise Sinatra::NotFound, "No test entry found" unless entry
      end
    end

    # POST "/tests/:entry" runs a test with the provided processorUrl.
    # the processor should return either JSON or some RDF formatted file
    # which is the result of performing the test.
    #
    # @method run_test
    # @param [String] testId last path component indicating particular test
    # @param [Hash{String => String}] params
    # @option params [String] :processorUrl
    #   URL of test endpoint, to which the source and run-time parameters are added.
    post '/tests/:testId' do
      processor_url = params.fetch("processorUrl", "http://example.org/reflector?uri=")

      entry = settings.manifest.entry(params[:testId])
      raise Sinatra::NotFound, "No test entry found" unless entry
    
      # Run the test, and re-serialize the entry, including test results
      entry.run(processor_url, logger: request.logger) do |extracted, status, error|
        respond_to do |wants|
          wants.jsonld {
            content_type :jsonld
            body entry.attributes.merge(
              "@context" =>    entry.context,
              extracted_loc:  (processor_url + entry.action_loc),
              extracted_body: extracted,
              status:         status,
              error:          (error.inspect if error)
            ).to_json
          }
        end
      end
    end

    # Angular route partials
    #
    # @method get_partial(view)
    # @overload get "/partials/:view"
    # @param [String] view Partial to return
    get "/partials/:view" do
      # If the file exists in /assets/partials, serve it directly from there
      if File.exist?(p = File.join(settings.root, "assets/partials/#{params[:view]}"))
        send_file p, type: 'text/html'
      else
        haml request.path.sub('.html', '').to_sym,
          layout: false,
          locals: {
            assertion: %([ a earl:Assertion;
  earl:assertedBy <>;
  earl:subject <{{processorDoap()}}>;
  earl:test &lt;#{CSVWTest::TEST_URI}{{test.id}}&gt;;
  earl:result [
   a earl:TestResult;
   earl:outcome earl:{{test.status.toLowerCase()}};
   dc:date \"{{test.date.toISOString()}}\"^^xsd:dateTime];
  earl:mode earl:automatic ] .)
          }
      end
    end

    # Return EARL preamble for selected processor
    #
    # @method get_earl(processorUrl)
    # @overload get "/earl"
    # @param [Hash{String => String}] params
    # @option params [String] :processorUrl
    #   ID of processor from processors.json, used to find DOAP information.
    get "/earl.?:ext?" do
      processors = JSON.parse(File.read(File.join(settings.root, "processors.json")))
      info = processors.detect {|p| p['endpoint'] == params['processorUrl']} || processors.last

      # Load DOAP definitions
      doap_url = info["doap_url"] || info["doap"]
      request.logger.info("Load doap info for #{params['processorId']} from #{doap_url}")
      if doap_url.start_with?('/')
        doap_doc = File.read(File.join(settings.root, doap_url))
      else
        doap_doc = RestClient.get(doap_url)
      end

      reader = RDF::Reader.for(doap_url) {doap_doc}
      unless reader.class == RDF::Turtle::Reader
        # Turn it into Turtle
        graph = RDF::Graph.new << reader.new(doap_doc)
        doap_doc = graph.dump(:ttl, standard_prefixes: true)
      end

      # Add EARL prefix, if necessary
      {
        foaf: RDF::FOAF.to_s,
        dc: RDF::DC.to_s,
        earl: "http://www.w3.org/ns/earl#",
        xsd: RDF::XSD.to_s
      }.each do |prefix, uri|
        doap_doc = "@prefix #{prefix}: #{uri} .\n" + doap_doc.to_s unless doap_doc.include?("@prefix #{prefix}}:")
      end

      respond_to(params[:ext]) do |wants|
        wants.json {
          etag doap_doc.hash
          content_type :json
          jbody = {doap: doap_doc}.to_json
          body jbody
        }
        wants.ttl {
          etag doap_doc.hash
          content_type :ttl
          body doap_doc
        }
      end
    end

    # Should use Rack::Conneg, but helpers not loading properly
    #
    # @param [Symbol] ext (type)
    #   optional extension to override accept matching
    def respond_to(type = nil)
      wants = { '*/*' => Proc.new { raise TypeError, "No handler for #{request.accept.join(',')}" } }
      def wants.method_missing(ext, *args, &handler)
        type = ext == :other ? '*/*' : Rack::Mime::MIME_TYPES[".#{ext.to_s}"]
        self[type] = handler
      end

      yield wants

      pref = if type
        Rack::Mime::MIME_TYPES[".#{type.to_s}"]
      else
        supported_types = wants.keys.map {|ext| Rack::Mime::MIME_TYPES[".#{ext.to_s}"]}.compact
        request.preferred_type(*supported_types)
      end
      (wants[pref.to_s] || wants['*/*']).call
    end

  end
end
