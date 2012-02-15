$:.<< File.dirname(__FILE__)

require 'sinatra'
require 'httparty'

module SeetemapClient
  class Application < Sinatra::Base
    include HTTParty
    base_uri 'seetemap.staging.synbioz.com'
    # format :xml

    get '/sitemap' do
      # auth_token, site_token = settings.seetemap_auth_token, settings.seetemap_site_token
      # STDOUT.puts "tokens = #{auth_token}, #{site_token}"
      # sitemap = Application.get "/dashboard/websites/#{site_token}.xml", :auth_token => auth_token
      # STDOUT.puts "sitemap = #{sitemap}"
    end

    # get '/sitemap.xml' do
    #   auth_token, site_token = settings.seetemap_auth_token, settings.seetemap_site_token
    #   STDOUT.puts "tokens xml = #{auth_token}, #{site_token}"
    #   sitemap = Application.get "/dashboard/websites/#{site_token}.xml", :auth_token => auth_token
    #   STDOUT.puts "sitemap = #{sitemap}"
    # end
  end
end