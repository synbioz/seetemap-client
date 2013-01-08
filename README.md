# How to use

- Add the `gem 'seetemap-client'` line to your Gemfile
- `bundle install`
- Create a `config/seetemap.yml` file

## Sinatra

- In application file add `require 'seetemap\_client'`
- For sinatra, use middleware in rackup file (config.ru), like this: `use SeetemapClient::Application`

## Rails

- In application.rb add `config.middleware.use "SeetemapClient::Application"`

# API

The application provides some entries points for the `seetemap.com` website and the `/sitemap.xml` for search engines.

## GET '/sitemap(.xml)'

When there is a hit on the server at this URL, we ask `seetemap.com` for informations about the last audits.

1. If `seetemap.com` does not respond with a code 200, then the response will be this code.
2. If there is no audit for the website, the response will be 204.
3. If there is no previous cached file, cache and serve a copy of the last sitemap found on `seetemap.com`.
4. If the cached copy is locally fresh (see the `keep_delay` configuration variable), serve it.
5. If the cached copy have been fetched after the last audit, serve and touch it.
6. Otherwise cache and serve a copy of the last sitemap found on `seetemap.com`.

With the version `0.0.13` (see `/seetemap/ping`), the step 4 and 5 will be the most used.

**Parameters:**

* add `force_reload` option to ignore the caching and fetch the last audit available from `seetemap.com`.


## GET '/seetemap/'

This is the namespece for any other API calls.

### GET '/seetemap/version'

Return 200 with the `Content-type` header set to `application/json`.

The response contains an single object containing one property: `version` and it is a string.

  {'version':'0.0.13'}

### GET '/seetemap/purge'

Return 200 with an empty body. When this request is received, the cached-copy of the sitemap is removed on the client side.

### GET '/seetemap/ping'

It tells the client that `seetemap.com` have a new audit ready for being fetched.

**Parameters:**

* the `fwd_google` option is added to the request if the user selected the associated option in the website administration, the option ping Google Webmaster Tools.

# Appendix

## The config/seetemap.yml config file

  development:
    auth_token: "account token"
    site_token: "api_key"
    keep_delay: 3600
