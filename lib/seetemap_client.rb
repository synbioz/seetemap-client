$:.<< File.dirname(__FILE__)

require 'sinatra'
require 'httparty'
require 'fileutils'
require 'yaml'

module SeetemapClient
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

    def render_sitemap(force_reload)
      path = "tmp/sitemap.xml"
      Seetemap.config(configuration[environment]["auth_token"], configuration[environment]["site_token"])
      code = Seetemap.fetch!
      case code
      when 200
        if File.exists?(path)
          time = File.mtime(path)
          if force_reload
            create_sitemap_file(path)
          elsif locally_fresh?(time)
            File.read(path)
          elsif (time_to_update = Seetemap.fresh?(time))
            FileUtils.touch path, :mtime => time_to_update
            File.read(path)
          else
            create_sitemap_file(path)
          end
        else
          create_sitemap_file(path)
        end
      else
        status code
        nil
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
