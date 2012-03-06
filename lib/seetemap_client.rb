$:.<< File.dirname(__FILE__)

require 'sinatra'
require 'httparty'
require 'fileutils'
require 'yaml'

module SeetemapClient
  class Seetemap
    include HTTParty
    base_uri 'seetemap.staging.synbioz.com'
    format :xml

    # hack: don't auto parse result
    parser(Proc.new { |body, format| body })

    def self.config(auth_token, site_token)
      @@auth_token = auth_token
      @@site_token = site_token
    end

    # Call ping! before or get an empty sitemap.
    #
    # @return [String] sitemap content
    def self.sitemap
      if self.available?
        get("/fr/dashboard/websites/#{@@site_token}.xml", :query => { :auth_token => @@auth_token })
      else
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\"></urlset>"
      end
    end

    # Cache the response inside the Seetemap class. Must be called for each
    # interaction with the server.
    def self.ping!
      @@response = get("/fr/dashboard/websites/#{@@site_token}.json", :format => :json, :query => { :auth_token => @@auth_token })
    end

    # Get the most recent timestamp that can be applyied to the audit when
    # there is no fresher audit available. Return nil if there is no audit
    # or no fresher audit.
    #
    # @param [Time] actual timestamp of the current cached sitemap
    # @return [nil|Time] nil if there is a fresher audit available or the time to update
    def self.fresh?(time)
      return nil if @@response.nil?
      case @@response["code"]
      when 0 # no available audits or error
        nil
      when 1 # a finished audit is available
        last_modified = Time.parse(@@response["audit"]["finished_at"]) rescue Time.now
        Time.now if time >= last_modified
      when 2 # only a running audit is available, use the previous audit
        Time.parse(@@response["audit"]["started_at"]) rescue Time.now
      end
    end

    # @return [Boolean] true if an audit is available, false otherwise
    def self.available?
      @@response and @@response["code"] == 1
    end
  end

  class Application < Sinatra::Base
    DEFAULT_CONF = {"keep_delay" => 3600}

    get '/sitemap' do
      content_type 'text/xml'
      render_sitemap
    end

    get '/sitemap.xml' do
      content_type 'text/xml'
      render_sitemap
    end

    private
    def environment
      @environment ||= ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
    end

    def configuration
      @configuration ||= DEFAULT_CONF.merge(YAML.load(File.open("config/seetemap.yml")))
    end

    def locally_fresh?(time)
      time > (Time.now - configuration[environment]["keep_delay"])
    end

    def render_sitemap
      path = "tmp/sitemap.xml"
      Seetemap.config(configuration[environment]["auth_token"], configuration[environment]["site_token"])
      Seetemap.ping!

      if File.exists?(path)
        time = File.mtime(path)
        # file has been considered fresh in the last day
        if locally_fresh?(time)
          File.read(path)
        # api tell us it's fresh
        elsif (time_to_update = Seetemap.fresh?(time))
          FileUtils.touch path, :mtime => time_to_update
          File.read(path)
        else
          create_sitemap_file(path)
        end
      else
        create_sitemap_file(path)
      end
    end

    def create_sitemap_file(path)
      base_path = File.dirname(path)
      Dir.mkdir(base_path) unless Dir.exists?(base_path)
      sitemap = Seetemap.sitemap
      File.open(path, "w+") { |file| file.write(sitemap) }
      sitemap.to_s
    end
  end
end
