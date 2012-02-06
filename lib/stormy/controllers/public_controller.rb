
# Copyright 2012 Sami Samhuri <sami@samhuri.net>

module Stormy
  class Server < Sinatra::Base

    get '/' do
      cache_control :public, :must_revalidate, :max_age => 60
      stylesheet 'index'
      stylesheet 'jquery.lightbox-0.5'
      script 'jquery.lightbox-0.5'
      script 'index'
      erb :index
    end

    get '/contact' do
      cache_control :public, :must_revalidate, :max_age => 60
      title 'Contact'
      stylesheet 'contact'
      script 'contact'
      erb :contact
    end

    post '/contact' do
      Pony.mail({
        :to      => 'info@example.com',
        :from    => params['email'],
        :subject => 'Stormy Weather Contact Form',
        :body    => params['message']
      })
      flash[:notice] = "Thanks for contacting us!"
      redirect '/contact'
    end

    get '/terms' do
      cache_control :public, :must_revalidate, :max_age => 60
      title 'Terms of Service'
      erb :terms
    end

    get '/faq' do
      @faq = faq
      title 'Frequently Asked Questions'
      stylesheet 'faq'
      erb :faq
    end

  end
end
