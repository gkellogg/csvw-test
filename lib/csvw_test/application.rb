require 'sinatra'
require 'sinatra/assetpack'
require 'sinatra/partial'
require 'digest/sha1'

module CSVWTest
  class Application < Sinatra::Base
    include Core

    configure do
      set :root, APP_DIR
      set :public_folder, PUB_DIR
      set :environment, ENV.fetch('RACK_ENV', 'development')
      set :views, ::File.expand_path('../views',  __FILE__)
      set :app_name, "The CSVW Test Harness"
      set :raise_errors, Proc.new { !settings.production? }
      set :partial_template_engine, :haml
      enable :logging
      disable :raise_errors, :show_exceptions if settings.environment == "production"

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

        js_compression  :jsmin
        css_compression :simple
      end
    end

    configure :development do
      set :logging, ::Logger.new($stdout)
      require "better_errors"
      use BetterErrors::Middleware
      BetterErrors.application_root = APP_DIR
    end

    helpers do
      # Set cache control
      def set_cache_header(options = {})
        options = {:max_age => ENV.fetch('max_age', 60*5)}.merge(options)
        cache_control(:public, :must_revalidate, options)
      end
    end

    before do
      request.logger.level = Logger::DEBUG unless settings.environment == 'production'
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

    # GET "/tests/" returns test-manifest with representation dependent on content-negotiation
    #
    # @method get_manifest
    get '/tests.?:ext?' do
      set_cache_header
      respond_to(params[:ext]) do |wants|
        wants.html {
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
    # If no entry is found, it looks for a file in the test directory
    #
    # @method get_entry
    # @param [String] testId last path component indicating particular test
    get '/tests/:testId' do
      if entry = get_entry(params[:testId])
        set_cache_header
        etag entry.hash
        content_type :jsonld
        entry.to_jsonld
      else
        # Otherwise, it might be a file
        pass
      end
    end

    # POST "/tests/:entry" runs a test with the provided extractor.
    # the extractor should return either JSON or some RDF formatted file
    # which is the result of performing the test.
    #
    # @method run_test
    # @param [String] testId last path component indicating particular test
    # @param [Hash{String => String}] params
    # @option params [String] :extractor
    #   URL of test endpoint, to which the source and run-time parameters are added.
    post '/tests/:testId' do
      extractor = params.fetch("extractor", "http://example.org/extractor?uri=")

      entry = get_entry(params[:testId])
      raise NotFound, "No test entry found" unless entry
    
      # Run the test, and re-serialize the entry, including test results
      entry.run(extractor)
      content_type :jsonld
      entry.to_jsonld
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
        haml request.path.sub('.html', '').to_sym, layout: false, locals: {}
      end
    end

    # Should use Rack::Conneg, but helpers not loading properly
    #
    # @param [Symbol] ext (type)
    #   optional extension to override accept matching
    def respond_to(type = nil)
      wants = { '*/*' => Proc.new { raise TypeError, "No handler for #{settings.accept.join(',')}" } }
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
