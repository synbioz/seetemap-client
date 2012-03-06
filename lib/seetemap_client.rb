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

    def self.sitemap
      get("/fr/dashboard/websites/#{@@site_token}.xml", :query => { :auth_token => @@auth_token })
    end

    def self.fresh?(time)
      r = head("/fr/dashboard/websites/#{@@site_token}.xml", :query => { :auth_token => @@auth_token })
      if r.headers.key? "etag"
        last_modified = Time.parse(r.headers["etag"]) rescue Time.now
        time >= last_modified
      else
        false
      end
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

      if File.exists?(path)
        time = File.mtime(path)
        # file has been considered fresh in the last day
        if locally_fresh?(time)
          File.read(path)
        # api tell us it's fresh
        elsif Seetemap.fresh?(time)
          FileUtils.touch path
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