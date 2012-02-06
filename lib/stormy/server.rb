# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'time'

require 'sinatra'
require 'sinatra/cookie_thief'
require 'sinatra/flash'

require 'erubis'
require 'json'
require 'pony'
require 'redis'
require 'redis-store'
require 'uuid'

# Ruby extensions
require 'hash-ext'

require 'stormy/models'
require 'stormy/controllers'
require 'stormy/helpers'

module Stormy

  class Server < Sinatra::Base

    set :port, 5000

    configure :production do
      enable :dump_errors

      # compress responses
      use Rack::Deflater

      # cache static files for an hour
      set :static_cache_control, [ :must_revalidate, :max_age => 60 ]
    end

    enable :logging

    # serve static files from /public, views from /views
    set :public_folder, File.dirname(__FILE__) + '/../../public'
    set :views, File.dirname(__FILE__) + '/../../views'

    # Automatically escape HTML
    set :erb, :escape_html => true

    # disable Rack::Protection, JsonCsrf breaks things
    disable :protection

    # disable cookies for static files
    register Sinatra::CookieThief

    register Sinatra::Flash

    use Rack::Session::Redis, {
      :httponly     => true,
      :secret       => '38066be6a9d388626e045be2351d26918608d53c',
      :expire_after => 8.hours
    }

    helpers Helpers::Accounts
    helpers Helpers::Admin
    helpers Helpers::Authorization
    helpers Helpers::FAQ
    helpers Helpers::Utils
    helpers Helpers::Views

    not_found do
      erb :'not-found'
    end

    error do
      if production?
        body = erb(:'email/error-notification', :layout => false, :locals => {
          :account  => current_account,
          :project => current_project,
          :admin    => current_admin,
          :error    => env['sinatra.error']
        })
        Pony.mail({
          :to      => 'admin@example.com',
          :from    => 'info@example.com',
          :subject => "[stormy] #{@error.class}: #{@error.message}",
          :headers => { 'Content-Type' => 'text/html' },
          :body    => body
        })
      end
      erb :error
    end

  end
end
