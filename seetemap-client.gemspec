# encoding: UTF-8

$:.push File.expand_path("../lib", __FILE__)

require "seetemap_client/version.rb"

Gem::Specification.new do |s|
  s.name              = "seetemap-client"
  s.version           = SeetemapClient::VERSION
  s.platform          = Gem::Platform::RUBY
  s.authors           = ["Synbioz"]
  s.email             = ["mcatty@synbioz.com"]
  s.homepage          = "https://github.com/synbioz/seetemap-client"
  s.summary           = "Client for seetemap."
  s.description       = "Seetemap allow you to add sitemap to your rack based app."

  s.add_runtime_dependency 'sinatra'
  s.add_runtime_dependency 'httparty'

  s.files        = Dir.glob("lib/**/*") + %w(README.md CHANGELOG.md)
  s.require_path = 'lib'
end
