$:.<< File.dirname(__FILE__)

require 'sinatra'
require 'httparty'
require 'fileutils'
require 'yaml'

require 'seetemap_client/version'

module SeetemapClient
  SITEMAP_PATH = "tmp/sitemap.xml"

  class Seetemap
    include HTTParty
    base_uri 'https://seetemap.com'

    # hack: don't auto parse result
    NO_PARSER = Proc.new { |body, format| body }

    def self.config(auth_token, site_token)
      @@auth_token = auth_token
      @@site_token = site_token
    end

    # You must be certain that fetch! returns a valid status code before calling
    # this function.
    #
    # @return [String] sitemap content
    def self.sitemap
      get("/fr/dashboard/websites/#{@@site_token}.xml",
          :format => :xml,
          :query => { :auth_token => @@auth_token },
          :parser => NO_PARSER)
    end

    # Cache the audit list inside the Seetemap class. Must be called for each
    # interaction with the server that need fresh information about the audits.
    #
    # This call returns an http code matching the current situation:
    # - 404 : no remote audit found, check your api_key
    # - 401 : your not authorized to get this site map, check your token
    # - 500 : server error / malformed response
    # - 204 : no audit is available
    # - 200 : an audit is available
    #
    # @return[Integer] response code
    def self.fetch!
      @@response = get("/fr/dashboard/websites/#{@@site_token}/audits.json",
                       :query => { :auth_token => @@auth_token })

      return @@response.code if @@response.nil? or @@response.code != 200

      @@last_audit          = @@response.parsed_response.first
      @@last_finished_audit = @@response.parsed_response.find {|audit| audit["finished_at"]}

      if @@last_audit.nil? or @@last_finished_audit.nil?
        204
      else
        200
      end
    end

    # Get the most recent timestamp that can be applyied to the audit when
    # there is no fresher audit available. 
    #
    # @param [Time] actual timestamp of the current cached sitemap
    # @return [nil|Time] nil if there is a fresher audit available or the time to update
    def self.fresh?(time)
      if @@last_audit.nil? or @@last_finished_audit.nil?
        nil
      else
        result = if @@last_audit["finished_at"].nil?
            Time.parse(@@last_audit["requested_at"]) rescue time
          else
            Time.now
          end
        last_modified = Time.parse(@@last_finished_audit["finished_at"]) rescue time
        time > last_modified ? result : nil
      end
    end

    def self.ping_google(mount_point)
      url = mount_point.chomp('/') << '/sitemap.xml'
      escaped_url = URI.escape(url, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
      HTTParty.get('http://www.google.com/webmasters/tools/ping?sitemap=' + escaped_url)
    end
  end

  class Application < Sinatra::Base
    get '/sitemap' do
      content_type 'text/xml'
      render_sitemap(params[:force_reload])
    end

    get '/sitemap.xml' do
      content_type 'text/xml'
      render_sitemap(params[:force_reload])
    end

    get '/seetemap/version' do
      content_type 'application/json'
      "{\"version\":\"#{SeetemapClient::VERSION}\"}"
    end

    get '/seetemap/purge' do
      remove_sitemap_file
      nil
    end

    get '/seetemap/ping' do
      Seetemap.config(configuration["auth_token"], configuration["site_token"])
      code = Seetemap.fetch!
      unless code != 200
        remove_sitemap_file
        create_sitemap_file
        if params[:fwd_google] && mount_point
          Seetemap.ping_google(mount_point)
        end
      end
      status code
    end

    private

    def environment
      @environment ||= ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"
    end

    def configuration
      @configuration ||= YAML.load(File.open("config/seetemap.yml"))[environment]
    end

    def mount_point
      configuration["mount_point"]
    end

    def locally_fresh?(time)
      time > (Time.now - configuration["keep_delay"] || 3600)
    end

    def render_sitemap(force_reload)
      Seetemap.config(configuration["auth_token"], configuration["site_token"])
      code = Seetemap.fetch!
      case code
      when 200
        if File.exists?(SeetemapClient::SITEMAP_PATH)
          time = File.mtime(SeetemapClient::SITEMAP_PATH)
          if force_reload
            create_sitemap_file
          elsif locally_fresh?(time)
            File.read(SeetemapClient::SITEMAP_PATH)
          elsif (time_to_update = Seetemap.fresh?(time))
            FileUtils.touch SeetemapClient::SITEMAP_PATH, :mtime => time_to_update
            File.read(SeetemapClient::SITEMAP_PATH)
          else
            create_sitemap_file
          end
        else
          create_sitemap_file
        end
      else
        status code
        nil
      end
    end

    def remove_sitemap_file
      if File.exists?(SeetemapClient::SITEMAP_PATH)
        File.delete(SeetemapClient::SITEMAP_PATH)
      end
    end

    def create_sitemap_file
      base_path = File.dirname(SeetemapClient::SITEMAP_PATH)
      Dir.mkdir(base_path) unless Dir.exists?(base_path)
      sitemap = Seetemap.sitemap
      File.open(SeetemapClient::SITEMAP_PATH, "w+") { |file| file.write(sitemap) }
      sitemap.to_s
    end
  end
end
