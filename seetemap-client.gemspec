# encoding: UTF-8

Gem::Specification.new do |s|
  s.name              = "seetemap-client"
  s.version           = "0.0.10"
  s.platform          = Gem::Platform::RUBY
  s.authors           = ["Synbioz"]
  s.email             = ["mcatty@synbioz.com"]
  s.summary           = "Client for seetemap."
  s.description       = "Seetemap allow you to add sitemap to your rack based app."

  s.add_runtime_dependency 'sinatra'
  s.add_runtime_dependency 'httparty'

  s.files        = Dir.glob("{app,test}/**/*") + %w(README.md CHANGELOG.md)
  s.require_path = 'lib'
end
