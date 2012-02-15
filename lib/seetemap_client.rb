$:.<< File.dirname(__FILE__)

require 'sinatra'
require 'httparty'

module SeetemapClient
  class Application < Sinatra::Base
    get '/sitemap' do
    end

    get '/sitemap.xml' do
    end
  end
end