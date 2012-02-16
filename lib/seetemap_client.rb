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
      get("/dashboard/websites/#{@@site_token}.xml", :query => { :auth_token => @@auth_token })
    end

    def self.fresh?
      # TODO
      false
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
    def configuration
      @configuration ||= YAML.load File.open("config/seetemap.yml")
    end

    def render_sitemap
      path = "tmp/sitemap.xml"
      Seetemap.config(configuration["seetemap"]["auth_token"], configuration["seetemap"]["site_token"])

      if File.exists?(path)
        # file has been considered fresh in the last day
        if File.mtime(path) > (Time.now - 86400)
          File.read(path)
        # api tell us it's fresh
        elsif Seetemap.fresh?
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