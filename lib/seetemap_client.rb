$:.<< File.dirname(__FILE__)

require 'sinatra'
require 'httparty'
require 'fileutils'
require 'yaml'

module SeetemapClient
  class Seetemap
    include HTTParty
    base_uri 'seetemap.staging.synbioz.com'

    # hack: don't auto parse result
    NO_PARSER = Proc.new { |body, format| body }

    def self.config(auth_token, site_token)
      @@auth_token = auth_token
      @@site_token = site_token
    end

    # Call fetch! before or you'll get an empty sitemap.
    #
    # @return [String] sitemap content
    def self.sitemap
      if self.available?
        get("/fr/dashboard/websites/#{@@site_token}.xml",
            :format => :xml,
            :query => { :auth_token => @@auth_token },
            :parser => NO_PARSER)
      else
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\"></urlset>"
      end
    end

    # Cache the audit list inside the Seetemap class. Must be called for each
    # interaction with the server that need fresh information about the audits.
    def self.fetch!
      @@response = get("/fr/dashboard/websites/#{@@site_token}/audits.json",
                       :query => { :auth_token => @@auth_token })
    end

    # Get the most recent timestamp that can be applyied to the audit when
    # there is no fresher audit available. Return nil if there is no audit
    # or no fresher audit.
    #
    # @param [Time] actual timestamp of the current cached sitemap
    # @return [nil|Time] nil if there is a fresher audit available or the time to update
    def self.fresh?(time)
      return nil if @@response.nil? or @@response.code != 200
     
      last_audit          = @@response.parsed_response.first 
      last_finished_audit = @@response.parsed_response.find {|audit| audit["finished_at"]}
      
      if last_audit.nil?
        Time.now
      elsif last_finished_audit.nil?
        Time.parse(last_audit["requested_at"]) rescue time
      else
        result = if last_audit["finished_at"].nil?
          Time.parse(last_audit["requested_at"]) rescue time
        else
          Time.now
        end
        last_modified = Time.parse(last_finished_audit["finished_at"]) rescue time
        result if time > last_modified
      end
    end

    # @return [Boolean] true if an audit is available, false otherwise
    def self.available?
      @@response and
        @@response.code == 200 and
        @@response.parsed_response.find {|audit| audit["finished_at"]}
    end
  end

  class Application < Sinatra::Base
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
      @configuration ||= YAML.load File.open("config/seetemap.yml")
    end

    def locally_fresh?(time)
      time > (Time.now - configuration[environment]["keep_delay"] || 3600)
    end

    def render_sitemap
      path = "tmp/sitemap.xml"
      Seetemap.config(configuration[environment]["auth_token"], configuration[environment]["site_token"])
      Seetemap.fetch!

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
      File.open(path, "w+") { |file| file.write(sitemap) } if Seetemap.available?
      sitemap.to_s
    end
  end
end
